// SPDX-License-Identifier: Apache-2.0

import java.io.BufferedOutputStream;
import java.io.IOException;
import java.io.InputStream;
import java.io.OutputStream;
import java.io.PrintWriter;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.StandardCopyOption;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.Comparator;
import java.util.List;
import java.util.TreeSet;
import java.util.spi.ToolProvider;
import java.util.stream.Collectors;
import java.util.stream.Stream;
import java.util.zip.GZIPOutputStream;
import java.util.zip.ZipEntry;
import java.util.zip.ZipInputStream;

/**
 * The elide_apidocs action, launched as a single-file program on the selected JDK (11 or later).
 *
 * <p>It unpacks the source jars into one source tree, runs javadoc in-process once in
 * unnamed-module {@code -sourcepath} mode (module descriptors are dropped), and packs the site
 * into a reproducible {@code .tar.gz}. The JDK's own tools do all of this, so the action needs
 * nothing from the host besides the runtime Bazel hands it.
 *
 * <p>Arguments (also accepted from {@code --argfile=FILE}, one per line): {@code --out DIR --archive FILE
 * [--srcjar JAR]... [--package PKG]... [--exclude PKG]... [--classpath PATH] --doclet CLASS
 * --docletpath PATH -- JAVADOC_OPTIONS...}. Without {@code --package}, every package found in the
 * source jars is documented.
 */
public final class ApiDocs {
  /** 1980-01-01T00:00:00Z, as SOURCE_DATE_EPOCH in the other rules_elide archives. */
  private static final long MTIME = 315532800L;

  public static void main(String[] argv) throws IOException {
    List<String> args = expand(argv);
    Path out = null;
    Path archive = null;
    String classpath = null;
    String doclet = null;
    String docletpath = null;
    List<Path> srcjars = new ArrayList<>();
    List<String> packages = new ArrayList<>();
    List<String> excludes = new ArrayList<>();
    List<String> extra = new ArrayList<>();
    for (int i = 0; i < args.size(); i++) {
      String arg = args.get(i);
      if (arg.equals("--")) {
        extra.addAll(args.subList(i + 1, args.size()));
        break;
      }
      String value = args.get(++i);
      if (arg.equals("--out")) {
        out = Path.of(value);
      } else if (arg.equals("--archive")) {
        archive = Path.of(value);
      } else if (arg.equals("--srcjar")) {
        srcjars.add(Path.of(value));
      } else if (arg.equals("--package")) {
        packages.add(value);
      } else if (arg.equals("--exclude")) {
        excludes.add(value);
      } else if (arg.equals("--classpath")) {
        classpath = value;
      } else if (arg.equals("--doclet")) {
        doclet = value;
      } else if (arg.equals("--docletpath")) {
        docletpath = value;
      } else {
        throw new IllegalArgumentException("Unknown argument: " + arg);
      }
    }
    if (out == null || archive == null || doclet == null || docletpath == null) {
      throw new IllegalArgumentException("--out, --archive, --doclet and --docletpath are required");
    }

    Path sources = Files.createTempDirectory("elide-apidocs-sources");
    TreeSet<String> found = new TreeSet<>();
    for (Path jar : srcjars) {
      unpack(jar, sources, found);
    }
    if (found.isEmpty()) {
      System.err.println("elide_apidocs: the source jars of deps contain no Java sources");
      System.exit(1);
    }

    List<String> javadoc = new ArrayList<>();
    javadoc.addAll(List.of("-d", out.toString(), "-sourcepath", sources.toString()));
    javadoc.addAll(List.of("-encoding", "UTF-8"));
    if (classpath != null && !classpath.isEmpty()) {
      javadoc.addAll(List.of("-classpath", classpath));
    }
    javadoc.addAll(List.of("-doclet", doclet, "-docletpath", docletpath));
    if (!excludes.isEmpty()) {
      javadoc.addAll(List.of("-exclude", String.join(":", excludes)));
    }
    javadoc.addAll(extra);
    if (packages.isEmpty()) {
      // Every package with sources; javadoc applies -exclude only to -subpackages.
      for (String pkg : found) {
        if (excludes.stream().noneMatch(e -> pkg.equals(e) || pkg.startsWith(e + "."))) {
          javadoc.add(pkg);
        }
      }
    } else {
      javadoc.addAll(List.of("-subpackages", String.join(":", packages)));
    }

    ToolProvider tool =
        ToolProvider.findFirst("javadoc")
            .orElseThrow(() -> new IllegalStateException("This JDK has no javadoc tool"));
    PrintWriter stdout = new PrintWriter(System.out, true);
    PrintWriter stderr = new PrintWriter(System.err, true);
    int status = tool.run(stdout, stderr, javadoc.toArray(new String[0]));
    stdout.flush();
    stderr.flush();
    if (status != 0) {
      System.exit(status);
    }
    tarGz(out, archive);
  }

  /** Arguments with {@code --argfile=FILE} entries replaced by the file's lines. */
  private static List<String> expand(String[] argv) throws IOException {
    List<String> args = new ArrayList<>();
    for (String arg : argv) {
      if (arg.startsWith("--argfile=")) {
        args.addAll(
            Files.readAllLines(Path.of(arg.substring("--argfile=".length())), StandardCharsets.UTF_8));
      } else {
        args.add(arg);
      }
    }
    return args;
  }

  /**
   * Unpacks {@code jar} into {@code root}, skipping metadata and module descriptors (documentation
   * runs in the unnamed module), and records the packages that hold Java sources.
   */
  private static void unpack(Path jar, Path root, TreeSet<String> packages) throws IOException {
    try (ZipInputStream zip = new ZipInputStream(Files.newInputStream(jar))) {
      for (ZipEntry entry; (entry = zip.getNextEntry()) != null; ) {
        String name = entry.getName();
        if (entry.isDirectory()
            || name.startsWith("META-INF/")
            || name.equals("module-info.java")
            || name.endsWith("/module-info.java")) {
          continue;
        }
        Path target = root.resolve(name).normalize();
        if (!target.startsWith(root)) {
          throw new IOException(jar + ": entry escapes the source tree: " + name);
        }
        if (Files.exists(target)) {
          // The first jar wins, as on a classpath; say so when they disagree.
          byte[] existing = Files.readAllBytes(target);
          byte[] incoming = zip.readAllBytes();
          if (!Arrays.equals(existing, incoming)) {
            System.err.println("elide_apidocs: warning: " + name + " in " + jar
                + " differs from an earlier source jar's copy; keeping the first");
          }
          continue;
        }
        Files.createDirectories(target.getParent());
        Files.copy(zip, target, StandardCopyOption.REPLACE_EXISTING);
        int slash = name.lastIndexOf('/');
        if (name.endsWith(".java") && slash > 0) {
          // Directories such as doc-files are not packages.
          String dir = name.substring(0, slash);
          if (!dir.contains("-")) {
            packages.add(dir.replace('/', '.'));
          }
        }
      }
    }
  }

  /** Packs {@code dir} into a gzip-compressed tar with sorted entries and fixed metadata. */
  private static void tarGz(Path dir, Path archive) throws IOException {
    List<Path> files;
    try (Stream<Path> walk = Files.walk(dir)) {
      files =
          walk.filter(p -> !p.equals(dir))
              .sorted(Comparator.comparing(p -> dir.relativize(p).toString().replace('\\', '/')))
              .collect(Collectors.toList());
    }
    try (OutputStream raw = new BufferedOutputStream(Files.newOutputStream(archive));
        GZIPOutputStream gz = new GZIPOutputStream(raw)) {
      for (Path file : files) {
        String name = dir.relativize(file).toString().replace('\\', '/');
        boolean directory = Files.isDirectory(file);
        if (directory) {
          name += "/";
        }
        long size = directory ? 0 : Files.size(file);
        writeHeader(gz, name, size, directory);
        if (!directory) {
          try (InputStream in = Files.newInputStream(file)) {
            in.transferTo(gz);
          }
          pad(gz, size);
        }
      }
      gz.write(new byte[1024]);
    }
  }

  private static void writeHeader(OutputStream out, String name, long size, boolean directory)
      throws IOException {
    byte[] bytes = name.getBytes(StandardCharsets.UTF_8);
    if (bytes.length > 100) {
      // A PAX extended header carries the full path; the ustar name is a truncated fallback.
      String record = " path=" + name + "\n";
      int length = record.getBytes(StandardCharsets.UTF_8).length;
      int digits = String.valueOf(length).length();
      int total = length + digits;
      if (String.valueOf(total).length() != digits) {
        total++;
      }
      byte[] pax = (total + record).getBytes(StandardCharsets.UTF_8);
      out.write(header("PaxHeaders/entry", pax.length, (byte) 'x'));
      out.write(pax);
      pad(out, pax.length);
      name = new String(Arrays.copyOf(bytes, 100), StandardCharsets.UTF_8);
    }
    out.write(header(name, size, directory ? (byte) '5' : (byte) '0'));
  }

  private static byte[] header(String name, long size, byte type) {
    byte[] block = new byte[512];
    byte[] bytes = name.getBytes(StandardCharsets.UTF_8);
    System.arraycopy(bytes, 0, block, 0, Math.min(bytes.length, 100));
    octal(block, 100, 8, type == '5' ? 0755 : 0644);
    octal(block, 108, 8, 0);
    octal(block, 116, 8, 0);
    octal(block, 124, 12, size);
    octal(block, 136, 12, MTIME);
    Arrays.fill(block, 148, 156, (byte) ' ');
    block[156] = type;
    System.arraycopy("ustar\0".getBytes(StandardCharsets.US_ASCII), 0, block, 257, 6);
    block[263] = '0';
    block[264] = '0';
    long sum = 0;
    for (byte b : block) {
      sum += b & 0xff;
    }
    octal(block, 148, 7, sum);
    return block;
  }

  private static void octal(byte[] block, int offset, int length, long value) {
    String digits = Long.toOctalString(value);
    String padded = "0".repeat(Math.max(0, length - 1 - digits.length())) + digits;
    byte[] bytes = padded.getBytes(StandardCharsets.US_ASCII);
    System.arraycopy(bytes, 0, block, offset, length - 1);
    block[offset + length - 1] = 0;
  }

  private static void pad(OutputStream out, long size) throws IOException {
    int remainder = (int) (size % 512);
    if (remainder != 0) {
      out.write(new byte[512 - remainder]);
    }
  }
}
