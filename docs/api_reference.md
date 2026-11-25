# API reference sites

`elide_apidocs` generates a static API reference from `JavaInfo` targets with a
custom doclet, [elide-dev/doclet](https://github.com/elide-dev/doclet) by default.
See the [generated attribute reference](apidocs.md) for every attribute.

```starlark
load("@rules_elide//elide:defs.bzl", "elide_apidocs")

elide_apidocs(
    name = "sdk_apidocs",
    deps = ["//sdk:polyglot", "//sdk:word"],
    doclet = "@elide_doclet//:doclet",
    packages = ["org.example.polyglot", "org.example.word"],
    exclude_packages = ["org.example.polyglot.tck"],
    title = "Example SDK",
    version = "1.0.0",
    theme = "//docs:theme.json",
    offline_links = {
        "https://docs.oracle.com/en/java/javase/25/docs/api/": "//docs:jdk_element_list",
    },
)
```

`bazel build //:sdk_apidocs` produces `sdk_apidocs_site/` (output group
`apidocs_site`) and `sdk_apidocs.tar.gz` (output group `apidocs_archive`).

## How the action works

- **Sources.** The source jars of `deps` (`JavaInfo.source_jars`, plus separate
  annotation-processor source jars unless `generated_sources = False`) are
  unpacked into one tree. `rules_java` already packs generated sources into the
  source jar, so `generated_sources = False` does not remove them there.
- **One javadoc run.** javadoc runs once in unnamed-module `-sourcepath` mode, as
  `mx javadoc --unified` does. Module descriptors are dropped, because the doclet
  documents one module. `packages` become `-subpackages`; with no `packages`,
  every package in the source jars is documented.
- **Classpath.** The transitive compile classpath of `deps` is the javadoc
  classpath. Public API that refers to classes that exist only in class jars,
  such as annotation-processor output in the GraalVM Truffle API, resolves.
- **JDK.** javadoc runs in-process in a small Java program on `java_runtime`.
  The default is the execution-platform runtime that `--tool_java_runtime_version`
  selects. elide-dev/doclet needs JDK 25, so set
  `--tool_java_runtime_version=remotejdk_25` or pass a JDK 25 `java_runtime`.
  Documenting GraalVM itself needs a JDK without GraalVM modules, such as
  LabsJDK: on a GraalVM JDK, javadoc fails with "package exists in another module".
- **JavaScript runtime.** The doclet renders through a JavaScript runtime. The
  action passes the Elide binary of the registered Elide toolchain as
  `APIDOCS_JS_RUNTIME`, and has no `PATH`, so it never picks up a host Node or Bun.
  Other doclets ignore the variable.
- **Archive.** The same program writes a gzip-compressed tar with sorted
  entries, fixed timestamps and owners, so archives are byte-for-byte
  reproducible. It is `.tar.gz`, not `.tar.zst`: the JDK has gzip but no
  Zstandard, and adding a zstd binary would mean a C toolchain or another
  downloaded tool in every consumer build.
- **Links.** `offline_links` maps a site URL to its `element-list` (a file, or a
  directory holding one) and needs no network access. `links` (`-link`) makes
  javadoc download the list; sandboxed and remote actions have no network, so
  the doclet warns and leaves those types unlinked.

The Elide doclet options (`module_name`, `version`, `theme`, `source_ref`,
`problems`) are passed only when set, so another doclet (`doclet_class`) does not
receive options it does not know. Put any other option in `javadoc_opts`.

## Building elide-dev/doclet

elide-dev/doclet has no release yet; pin a commit and build its jar in Bazel.
[`e2e/apidocs`](../e2e/apidocs/) does this with an `http_archive` and a BUILD
overlay:

```starlark
# MODULE.bazel
http_archive = use_repo_rule("@bazel_tools//tools/build_defs/repo:http.bzl", "http_archive")

http_archive(
    name = "elide_doclet",
    build_file = "//:doclet.BUILD.bazel",
    integrity = "sha256-...",
    strip_prefix = "doclet-<commit>",
    urls = ["https://github.com/elide-dev/doclet/archive/<commit>.tar.gz"],
)
```

Copy [`doclet.BUILD.bazel`](../e2e/apidocs/doclet.BUILD.bazel): one
`java_library` over `doclet/src/main/java` and `doclet/src/apidocs/java`, with
the renderer under `doclet/src/main/resources`, the same jar `elide build`
produces. The doclet has no Maven dependencies. It compiles at Java 25, so the
workspace sets `--java_language_version=25` and `--tool_java_language_version=25`
with the matching `remotejdk_25` runtimes (see
[`e2e/apidocs/.bazelrc`](../e2e/apidocs/.bazelrc)). The `doclet` attribute also
accepts a prebuilt jar.
