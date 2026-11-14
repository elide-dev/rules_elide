package dev.elide.bazel;

import dev.elide.bazel.WorkerProtocol.Input;
import dev.elide.bazel.WorkerProtocol.WorkRequest;
import dev.elide.bazel.WorkerProtocol.WorkResponse;
import java.io.File;
import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.security.MessageDigest;
import java.util.ArrayDeque;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.Base64;
import java.util.Comparator;
import java.util.HashSet;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.TimeUnit;
import java.util.stream.Collectors;
import java.util.zip.ZipEntry;
import java.util.zip.ZipOutputStream;

/**
 * Keeps Kotlin IC classes and caches together, publishing complete Bazel jar outputs.
 *
 * <p>Multiplex requests are handled concurrently. Elide compiles one request at a time per
 * process, so the worker keeps a pool of resident compilers, started on demand. A target's
 * classes and IC cache live on disk in this worker's scratch directory, so any compiler in the
 * pool can serve it; Bazel never runs two compiles of one target at once.
 */
public final class IncrementalWorker implements AutoCloseable {
  private static final class State {
    final String signature;
    final Path root;

    State(String signature, Path root) {
      this.signature = signature;
      this.root = root;
    }
  }

  private final String elide;
  private final Path scratch;
  private final Map<Path, State> states = new ConcurrentHashMap<>();
  // Resident compilers: `idle` are free, `compilers` are all that are running. Guarded by `this`.
  private final int limit = Math.max(1, Math.min(8, Runtime.getRuntime().availableProcessors()));
  private final Set<Process> compilers = new HashSet<>();
  private final ArrayDeque<Process> idle = new ArrayDeque<>();
  private boolean closed;

  private IncrementalWorker(String elide) throws IOException {
    this.elide = Path.of(elide).toAbsolutePath().toString();
    scratch = Files.createTempDirectory("elide-bazel-ic-");
  }

  private static void remove(Path root) throws IOException {
    if (!Files.exists(root)) return;
    try (var paths = Files.walk(root)) {
      for (Path p : paths.sorted(Comparator.reverseOrder()).collect(Collectors.toList())) Files.delete(p);
    }
  }

  private static void hash(MessageDigest hash, byte[] bytes) {
    // Length prefixes keep argument boundaries unambiguous.
    hash.update(java.nio.ByteBuffer.allocate(4).putInt(bytes.length).array());
    hash.update(bytes);
  }

  static String signature(WorkRequest request) throws Exception {
    // Native IC snapshots ordinary classpath jars and invalidates affected sources.
    // Keep full resets for plugins/friends, whose extra reads are not covered here.
    Set<String> classpath = new HashSet<>();
    List<String> arguments = request.getArgumentsList();
    boolean conservative = arguments.stream().anyMatch(arg ->
        arg.startsWith("-Xplugin") || arg.startsWith("-Xcompiler-plugin")
            || arg.equals("-P") || arg.startsWith("-P=") || arg.startsWith("-Xfriend-paths")
            || arg.equals("--plugins") || arg.startsWith("--plugins="));
    if (!conservative) {
      for (int i = arguments.indexOf("--") + 1; i + 1 < arguments.size(); i++) {
        if (arguments.get(i).equals("-classpath") || arguments.get(i).equals("-cp")) {
          for (String entry : arguments.get(++i).split(java.util.regex.Pattern.quote(File.pathSeparator))) {
            // Directory inputs may have children with separate digests. Keep their reset behavior.
            if (entry.endsWith(".jar")) classpath.add(entry);
          }
        }
      }
    }
    MessageDigest hash = MessageDigest.getInstance("SHA-256");
    for (String arg : request.getArgumentsList()) {
      hash(hash, arg.getBytes(java.nio.charset.StandardCharsets.UTF_8));
    }
    // Native IC tracks source and ordinary classpath content edits. Other changes
    // invalidate both cache and output, including flags and added/deleted sources.
    for (Input input : request.getInputsList().stream()
        .sorted(Comparator.comparing(Input::getPath)).collect(Collectors.toList())) {
      if (input.getPath().endsWith(".kt") || input.getPath().endsWith(".java")
          || classpath.contains(input.getPath())) continue;
      hash(hash, input.getPath().getBytes(java.nio.charset.StandardCharsets.UTF_8));
      hash(hash, input.getDigest());
    }
    return Base64.getEncoder().encodeToString(hash.digest());
  }

  /** Takes an idle compiler, starting one below the limit and otherwise waiting for a release. */
  private synchronized Process acquire() throws IOException, InterruptedException {
    while (true) {
      if (closed) throw new IOException("IC worker is shutting down");
      Process free = idle.pollLast();
      if (free != null) {
        if (free.isAlive()) return free;
        compilers.remove(free);
        continue;
      }
      if (compilers.size() < limit) {
        Process started = new ProcessBuilder(elide, "--safe-close", "kotlinc", "--persistent_worker")
            .redirectError(ProcessBuilder.Redirect.INHERIT).start();
        compilers.add(started);
        return started;
      }
      wait();
    }
  }

  private synchronized void release(Process compiler) {
    idle.addLast(compiler);
    notify();
  }

  /** Drops a compiler whose state is unknown after a failure. */
  private synchronized void discard(Process compiler) {
    compiler.destroyForcibly();
    compilers.remove(compiler);
    notify();
  }

  private WorkResponse compile(WorkRequest request) throws IOException, InterruptedException {
    Process compiler = acquire();
    try {
      request.writeDelimitedTo(compiler.getOutputStream());
      compiler.getOutputStream().flush();
      WorkResponse response = WorkResponse.parseDelimitedFrom(compiler.getInputStream());
      if (response == null || response.getRequestId() != request.getRequestId()) {
        throw new IOException("Elide incremental worker closed or returned a mismatched request ID");
      }
      release(compiler);
      return response;
    } catch (IOException | RuntimeException failure) {
      discard(compiler);
      throw failure;
    }
  }

  private static void pack(Path classes, Path jar) throws IOException {
    Files.createDirectories(jar.getParent());
    try (var files = Files.walk(classes);
        var output = new ZipOutputStream(Files.newOutputStream(jar))) {
      for (Path file : files.filter(Files::isRegularFile).sorted().collect(Collectors.toList())) {
        ZipEntry entry = new ZipEntry(classes.relativize(file).toString().replace('\\', '/'));
        entry.setTime(0);
        output.putNextEntry(entry);
        Files.copy(file, output);
        output.closeEntry();
      }
    }
  }

  private WorkResponse handle(WorkRequest request) throws Exception {
    List<String> args = new ArrayList<>(request.getArgumentsList());
    int separator = args.indexOf("--");
    int destination = args.indexOf("-d");
    if (separator < 0 || destination <= separator || destination + 1 >= args.size()) {
      throw new IllegalArgumentException("IC worker requires -- ... -d <output.jar>");
    }
    Path output = Path.of(args.get(destination + 1)).toAbsolutePath().normalize();
    String signature = signature(request);
    State state = states.get(output);
    if (state == null || !signature.equals(state.signature) || request.getInputsCount() == 0) {
      if (state != null) remove(state.root);
      state = new State(signature, Files.createTempDirectory(scratch, "target-"));
      states.put(output, state);
    }
    Path classes = state.root.resolve("classes");
    Files.createDirectories(classes);
    args.set(destination + 1, classes.toString());
    args.addAll(separator, List.of("--incremental", "--incremental-cache-dir",
        state.root.resolve("cache").toString()));
    try {
      WorkResponse response = compile(request.withArguments(args));
      if (response.getExitCode() == 0) {
        pack(classes, output);
      } else {
        states.remove(output);
        remove(state.root);
      }
      return response;
    } catch (Exception failure) {
      // Unknown state is never reused after a transport, compile, or publication failure: the
      // compiler was discarded, and this target starts fresh. Other targets keep their state.
      states.remove(output);
      remove(state.root);
      throw failure;
    }
  }

  @Override
  public void close() throws IOException {
    List<Process> running;
    synchronized (this) {
      closed = true;
      running = new ArrayList<>(compilers);
      compilers.clear();
      idle.clear();
      notifyAll();
    }
    try {
      for (Process compiler : running) {
        try {
          compiler.getOutputStream().close();
        } catch (IOException ignored) {
          // The compiler already exited.
        }
      }
      for (Process compiler : running) {
        try {
          compiler.waitFor(10, TimeUnit.SECONDS);
        } catch (InterruptedException interrupted) {
          Thread.currentThread().interrupt();
        }
        if (compiler.isAlive()) compiler.destroyForcibly();
      }
    } finally {
      remove(scratch);
    }
  }

  private static void respond(IncrementalWorker worker, WorkRequest request) {
    try {
      WorkResponse response;
      try {
        response = worker.handle(request);
      } catch (Exception failure) {
        response = WorkResponse.error(request.getRequestId(), failure.toString());
      }
      synchronized (System.out) {
        response.writeDelimitedTo(System.out);
        System.out.flush();
      }
    } catch (IOException failure) {
      throw new java.io.UncheckedIOException(failure);
    }
  }

  public static void main(String[] argv) throws Exception {
    if (argv.length == 0 || !argv[0].startsWith("--elide=")) {
      throw new IllegalArgumentException("Expected --elide=<compiler>");
    }
    IncrementalWorker worker = new IncrementalWorker(argv[0].substring("--elide=".length()));
    Thread cleanup = new Thread(() -> {
      try {
        worker.close();
      } catch (IOException failure) {
        System.err.println("IC worker cleanup failed: " + failure);
      }
    });
    Runtime.getRuntime().addShutdownHook(cleanup);
    try (worker) {
      List<String> args = Arrays.asList(argv).subList(1, argv.length);
      if (args.contains("--persistent_worker")) {
        // A singleplex request (ID 0) is handled inline; multiplex requests run concurrently.
        ExecutorService requests = Executors.newCachedThreadPool(task -> {
          Thread thread = new Thread(task, "ic-request");
          thread.setDaemon(true);
          return thread;
        });
        try {
          WorkRequest next;
          while ((next = WorkRequest.parseDelimitedFrom(System.in)) != null) {
            WorkRequest request = next;
            if (request.getRequestId() == 0) respond(worker, request);
            else requests.execute(() -> respond(worker, request));
          }
        } finally {
          requests.shutdown();
          requests.awaitTermination(1, TimeUnit.HOURS);
        }
      } else {
        List<String> expanded = new ArrayList<>();
        for (String arg : args) {
          if (arg.startsWith("@")) expanded.addAll(Files.readAllLines(Path.of(arg.substring(1))));
          else expanded.add(arg);
        }
        WorkResponse response = worker.handle(WorkRequest.create(expanded));
        System.err.print(response.getOutput());
        if (response.getExitCode() != 0) throw new IOException("Kotlin compilation failed");
      }
    } finally {
      try {
        Runtime.getRuntime().removeShutdownHook(cleanup);
      } catch (IllegalStateException shuttingDown) {
        // The shutdown hook is already responsible for cleanup.
      }
    }
  }
}
