package dev.elide.bazel;

import dev.elide.bazel.WorkerProtocol.Input;
import dev.elide.bazel.WorkerProtocol.WorkRequest;
import dev.elide.bazel.WorkerProtocol.WorkResponse;
import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.security.MessageDigest;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.Base64;
import java.util.Comparator;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.stream.Collectors;
import java.util.zip.ZipEntry;
import java.util.zip.ZipOutputStream;

/** Keeps Kotlin IC classes and caches together, publishing complete Bazel jar outputs. */
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
  private final Map<Path, State> states = new HashMap<>();
  private Process compiler;

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

  private static String signature(WorkRequest request) throws Exception {
    MessageDigest hash = MessageDigest.getInstance("SHA-256");
    for (String arg : request.getArgumentsList()) {
      hash(hash, arg.getBytes(java.nio.charset.StandardCharsets.UTF_8));
    }
    // Native IC tracks source-content edits. All other changes invalidate both
    // the cache and the output tree, including flags and added/deleted sources.
    for (Input input : request.getInputsList().stream()
        .sorted(Comparator.comparing(Input::getPath)).collect(Collectors.toList())) {
      if (input.getPath().endsWith(".kt") || input.getPath().endsWith(".java")) continue;
      hash(hash, input.getPath().getBytes(java.nio.charset.StandardCharsets.UTF_8));
      hash(hash, input.getDigest());
    }
    return Base64.getEncoder().encodeToString(hash.digest());
  }

  private WorkResponse compile(WorkRequest request) throws IOException {
    if (compiler == null) {
      compiler = new ProcessBuilder(elide, "--safe-close", "kotlinc", "--persistent_worker")
          .redirectError(ProcessBuilder.Redirect.INHERIT).start();
    }
    request.writeDelimitedTo(compiler.getOutputStream());
    compiler.getOutputStream().flush();
    WorkResponse response = WorkResponse.parseDelimitedFrom(compiler.getInputStream());
    if (response == null || response.getRequestId() != request.getRequestId()) {
      throw new IOException("Elide incremental worker closed or returned a mismatched request ID");
    }
    return response;
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
      // Unknown compiler state is never reused after transport, compile, or publication failure.
      states.clear();
      if (compiler != null) compiler.destroyForcibly();
      compiler = null;
      remove(scratch);
      Files.createDirectories(scratch);
      throw failure;
    }
  }

  @Override
  public synchronized void close() throws IOException {
    try {
      if (compiler != null) {
        compiler.getOutputStream().close();
        try {
          compiler.waitFor(10, java.util.concurrent.TimeUnit.SECONDS);
        } catch (InterruptedException interrupted) {
          Thread.currentThread().interrupt();
        }
      }
    } finally {
      if (compiler != null && compiler.isAlive()) compiler.destroyForcibly();
      compiler = null;
      remove(scratch);
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
        WorkRequest request;
        while ((request = WorkRequest.parseDelimitedFrom(System.in)) != null) {
          WorkResponse response;
          try {
            response = worker.handle(request);
          } catch (Exception failure) {
            response = WorkResponse.error(request.getRequestId(), failure.toString());
          }
          response.writeDelimitedTo(System.out);
          System.out.flush();
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
