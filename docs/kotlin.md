<!-- Generated with Stardoc: http://skydoc.bazel.build -->

Kotlin compile rules for rules_elide.

`elide_kotlin_library` / `_binary` / `_test` drive `elide kotlinc` to compile
mixed `.kt` / `.java` sources. Every rule returns `JavaInfo` (with an
`ijar`-derived `compile_jar` and a packed `source_jar`) for seamless interop
with `rules_java` / `rules_kotlin` consumers, plus `ElideInfo` for
Elide-specific metadata propagation.

<a id="elide_kotlin_binary"></a>

## elide_kotlin_binary

<pre>
load("@rules_elide//elide/rules:kotlin.bzl", "elide_kotlin_binary")

elide_kotlin_binary(<a href="#elide_kotlin_binary-name">name</a>, <a href="#elide_kotlin_binary-deps">deps</a>, <a href="#elide_kotlin_binary-srcs">srcs</a>, <a href="#elide_kotlin_binary-data">data</a>, <a href="#elide_kotlin_binary-resources">resources</a>, <a href="#elide_kotlin_binary-associates">associates</a>, <a href="#elide_kotlin_binary-builtin_plugins">builtin_plugins</a>,
                    <a href="#elide_kotlin_binary-exported_compiler_plugins">exported_compiler_plugins</a>, <a href="#elide_kotlin_binary-exports">exports</a>, <a href="#elide_kotlin_binary-javac_opts">javac_opts</a>, <a href="#elide_kotlin_binary-jvm_flags">jvm_flags</a>, <a href="#elide_kotlin_binary-kotlinc_opts">kotlinc_opts</a>,
                    <a href="#elide_kotlin_binary-main_class">main_class</a>, <a href="#elide_kotlin_binary-module_name">module_name</a>, <a href="#elide_kotlin_binary-neverlink">neverlink</a>, <a href="#elide_kotlin_binary-plugins">plugins</a>, <a href="#elide_kotlin_binary-resource_jars">resource_jars</a>, <a href="#elide_kotlin_binary-resource_strip_prefix">resource_strip_prefix</a>,
                    <a href="#elide_kotlin_binary-runtime_deps">runtime_deps</a>)
</pre>



**ATTRIBUTES**


| Name  | Description | Type | Mandatory | Default |
| :------------- | :------------- | :------------- | :------------- | :------------- |
| <a id="elide_kotlin_binary-name"></a>name |  A unique name for this target.   | <a href="https://bazel.build/concepts/labels#target-names">Name</a> | required |  |
| <a id="elide_kotlin_binary-deps"></a>deps |  Compile-time dependencies. Targets must provide JavaInfo.   | <a href="https://bazel.build/concepts/labels">List of labels</a> | optional |  `[]`  |
| <a id="elide_kotlin_binary-srcs"></a>srcs |  Kotlin (and optionally Java) source files to compile via `elide kotlinc`.   | <a href="https://bazel.build/concepts/labels">List of labels</a> | optional |  `[]`  |
| <a id="elide_kotlin_binary-data"></a>data |  Files made available to this target's runfiles at action time.   | <a href="https://bazel.build/concepts/labels">List of labels</a> | optional |  `[]`  |
| <a id="elide_kotlin_binary-resources"></a>resources |  Resource files packaged into the output JAR alongside compiled classes.   | <a href="https://bazel.build/concepts/labels">List of labels</a> | optional |  `[]`  |
| <a id="elide_kotlin_binary-associates"></a>associates |  Targets whose compile jars become Kotlin friend-paths (grants internal visibility).   | <a href="https://bazel.build/concepts/labels">List of labels</a> | optional |  `[]`  |
| <a id="elide_kotlin_binary-builtin_plugins"></a>builtin_plugins |  Builtin Kotlin compiler plugins to enable by name via `elide kotlinc --plugins` (e.g. "serialization", "metro", "atomicfu", "power-assert"). Use to force on plugins the classpath heuristic may miss (notably Metro). Note: an explicit suite does not yet fully disable heuristic-detected plugins it omits (WHIPLASH#1119).   | List of strings | optional |  `[]`  |
| <a id="elide_kotlin_binary-exported_compiler_plugins"></a>exported_compiler_plugins |  Compiler plugins propagated to direct rdeps via ElideInfo (mirrors java_plugin.exported_plugins).   | <a href="https://bazel.build/concepts/labels">List of labels</a> | optional |  `[]`  |
| <a id="elide_kotlin_binary-exports"></a>exports |  Targets re-exported to direct rdeps (transitive compile classpath).   | <a href="https://bazel.build/concepts/labels">List of labels</a> | optional |  `[]`  |
| <a id="elide_kotlin_binary-javac_opts"></a>javac_opts |  Flags forwarded to javac through kotlinc (`-Xjavac-arguments=`).   | List of strings | optional |  `[]`  |
| <a id="elide_kotlin_binary-jvm_flags"></a>jvm_flags |  Flags passed to the JVM when running the binary.   | List of strings | optional |  `[]`  |
| <a id="elide_kotlin_binary-kotlinc_opts"></a>kotlinc_opts |  Flags appended to the `elide kotlinc --` invocation.   | List of strings | optional |  `[]`  |
| <a id="elide_kotlin_binary-main_class"></a>main_class |  Fully qualified main class.   | String | required |  |
| <a id="elide_kotlin_binary-module_name"></a>module_name |  Kotlin module name (`-module-name`).   | String | optional |  `""`  |
| <a id="elide_kotlin_binary-neverlink"></a>neverlink |  If true, outputs are used only for compilation, not packaged into binaries.   | Boolean | optional |  `False`  |
| <a id="elide_kotlin_binary-plugins"></a>plugins |  Compiler plugins for this compilation (only). Targets must provide JavaInfo.   | <a href="https://bazel.build/concepts/labels">List of labels</a> | optional |  `[]`  |
| <a id="elide_kotlin_binary-resource_jars"></a>resource_jars |  Pre-built JARs whose contents are merged into the output JAR.   | <a href="https://bazel.build/concepts/labels">List of labels</a> | optional |  `[]`  |
| <a id="elide_kotlin_binary-resource_strip_prefix"></a>resource_strip_prefix |  Workspace-root-relative path prefix stripped from each `resources` entry when computing its in-JAR location (mirrors java_library.resource_strip_prefix). Empty -> use the full short_path.   | String | optional |  `""`  |
| <a id="elide_kotlin_binary-runtime_deps"></a>runtime_deps |  Runtime-only dependencies (excluded from compile classpath).   | <a href="https://bazel.build/concepts/labels">List of labels</a> | optional |  `[]`  |


<a id="elide_kotlin_library"></a>

## elide_kotlin_library

<pre>
load("@rules_elide//elide/rules:kotlin.bzl", "elide_kotlin_library")

elide_kotlin_library(<a href="#elide_kotlin_library-name">name</a>, <a href="#elide_kotlin_library-deps">deps</a>, <a href="#elide_kotlin_library-srcs">srcs</a>, <a href="#elide_kotlin_library-data">data</a>, <a href="#elide_kotlin_library-resources">resources</a>, <a href="#elide_kotlin_library-associates">associates</a>, <a href="#elide_kotlin_library-builtin_plugins">builtin_plugins</a>,
                     <a href="#elide_kotlin_library-exported_compiler_plugins">exported_compiler_plugins</a>, <a href="#elide_kotlin_library-exports">exports</a>, <a href="#elide_kotlin_library-javac_opts">javac_opts</a>, <a href="#elide_kotlin_library-kotlinc_opts">kotlinc_opts</a>, <a href="#elide_kotlin_library-module_name">module_name</a>,
                     <a href="#elide_kotlin_library-neverlink">neverlink</a>, <a href="#elide_kotlin_library-plugins">plugins</a>, <a href="#elide_kotlin_library-resource_jars">resource_jars</a>, <a href="#elide_kotlin_library-resource_strip_prefix">resource_strip_prefix</a>, <a href="#elide_kotlin_library-runtime_deps">runtime_deps</a>)
</pre>



**ATTRIBUTES**


| Name  | Description | Type | Mandatory | Default |
| :------------- | :------------- | :------------- | :------------- | :------------- |
| <a id="elide_kotlin_library-name"></a>name |  A unique name for this target.   | <a href="https://bazel.build/concepts/labels#target-names">Name</a> | required |  |
| <a id="elide_kotlin_library-deps"></a>deps |  Compile-time dependencies. Targets must provide JavaInfo.   | <a href="https://bazel.build/concepts/labels">List of labels</a> | optional |  `[]`  |
| <a id="elide_kotlin_library-srcs"></a>srcs |  Kotlin (and optionally Java) source files to compile via `elide kotlinc`.   | <a href="https://bazel.build/concepts/labels">List of labels</a> | optional |  `[]`  |
| <a id="elide_kotlin_library-data"></a>data |  Files made available to this target's runfiles at action time.   | <a href="https://bazel.build/concepts/labels">List of labels</a> | optional |  `[]`  |
| <a id="elide_kotlin_library-resources"></a>resources |  Resource files packaged into the output JAR alongside compiled classes.   | <a href="https://bazel.build/concepts/labels">List of labels</a> | optional |  `[]`  |
| <a id="elide_kotlin_library-associates"></a>associates |  Targets whose compile jars become Kotlin friend-paths (grants internal visibility).   | <a href="https://bazel.build/concepts/labels">List of labels</a> | optional |  `[]`  |
| <a id="elide_kotlin_library-builtin_plugins"></a>builtin_plugins |  Builtin Kotlin compiler plugins to enable by name via `elide kotlinc --plugins` (e.g. "serialization", "metro", "atomicfu", "power-assert"). Use to force on plugins the classpath heuristic may miss (notably Metro). Note: an explicit suite does not yet fully disable heuristic-detected plugins it omits (WHIPLASH#1119).   | List of strings | optional |  `[]`  |
| <a id="elide_kotlin_library-exported_compiler_plugins"></a>exported_compiler_plugins |  Compiler plugins propagated to direct rdeps via ElideInfo (mirrors java_plugin.exported_plugins).   | <a href="https://bazel.build/concepts/labels">List of labels</a> | optional |  `[]`  |
| <a id="elide_kotlin_library-exports"></a>exports |  Targets re-exported to direct rdeps (transitive compile classpath).   | <a href="https://bazel.build/concepts/labels">List of labels</a> | optional |  `[]`  |
| <a id="elide_kotlin_library-javac_opts"></a>javac_opts |  Flags forwarded to javac through kotlinc (`-Xjavac-arguments=`).   | List of strings | optional |  `[]`  |
| <a id="elide_kotlin_library-kotlinc_opts"></a>kotlinc_opts |  Flags appended to the `elide kotlinc --` invocation.   | List of strings | optional |  `[]`  |
| <a id="elide_kotlin_library-module_name"></a>module_name |  Kotlin module name (`-module-name`).   | String | optional |  `""`  |
| <a id="elide_kotlin_library-neverlink"></a>neverlink |  If true, outputs are used only for compilation, not packaged into binaries.   | Boolean | optional |  `False`  |
| <a id="elide_kotlin_library-plugins"></a>plugins |  Compiler plugins for this compilation (only). Targets must provide JavaInfo.   | <a href="https://bazel.build/concepts/labels">List of labels</a> | optional |  `[]`  |
| <a id="elide_kotlin_library-resource_jars"></a>resource_jars |  Pre-built JARs whose contents are merged into the output JAR.   | <a href="https://bazel.build/concepts/labels">List of labels</a> | optional |  `[]`  |
| <a id="elide_kotlin_library-resource_strip_prefix"></a>resource_strip_prefix |  Workspace-root-relative path prefix stripped from each `resources` entry when computing its in-JAR location (mirrors java_library.resource_strip_prefix). Empty -> use the full short_path.   | String | optional |  `""`  |
| <a id="elide_kotlin_library-runtime_deps"></a>runtime_deps |  Runtime-only dependencies (excluded from compile classpath).   | <a href="https://bazel.build/concepts/labels">List of labels</a> | optional |  `[]`  |


<a id="elide_kotlin_test"></a>

## elide_kotlin_test

<pre>
load("@rules_elide//elide/rules:kotlin.bzl", "elide_kotlin_test")

elide_kotlin_test(<a href="#elide_kotlin_test-name">name</a>, <a href="#elide_kotlin_test-deps">deps</a>, <a href="#elide_kotlin_test-srcs">srcs</a>, <a href="#elide_kotlin_test-data">data</a>, <a href="#elide_kotlin_test-resources">resources</a>, <a href="#elide_kotlin_test-associates">associates</a>, <a href="#elide_kotlin_test-builtin_plugins">builtin_plugins</a>,
                  <a href="#elide_kotlin_test-exported_compiler_plugins">exported_compiler_plugins</a>, <a href="#elide_kotlin_test-exports">exports</a>, <a href="#elide_kotlin_test-javac_opts">javac_opts</a>, <a href="#elide_kotlin_test-jvm_flags">jvm_flags</a>, <a href="#elide_kotlin_test-kotlinc_opts">kotlinc_opts</a>,
                  <a href="#elide_kotlin_test-module_name">module_name</a>, <a href="#elide_kotlin_test-neverlink">neverlink</a>, <a href="#elide_kotlin_test-plugins">plugins</a>, <a href="#elide_kotlin_test-resource_jars">resource_jars</a>, <a href="#elide_kotlin_test-resource_strip_prefix">resource_strip_prefix</a>, <a href="#elide_kotlin_test-runtime_deps">runtime_deps</a>,
                  <a href="#elide_kotlin_test-test_class">test_class</a>)
</pre>



**ATTRIBUTES**


| Name  | Description | Type | Mandatory | Default |
| :------------- | :------------- | :------------- | :------------- | :------------- |
| <a id="elide_kotlin_test-name"></a>name |  A unique name for this target.   | <a href="https://bazel.build/concepts/labels#target-names">Name</a> | required |  |
| <a id="elide_kotlin_test-deps"></a>deps |  Compile-time dependencies. Targets must provide JavaInfo.   | <a href="https://bazel.build/concepts/labels">List of labels</a> | optional |  `[]`  |
| <a id="elide_kotlin_test-srcs"></a>srcs |  Kotlin (and optionally Java) source files to compile via `elide kotlinc`.   | <a href="https://bazel.build/concepts/labels">List of labels</a> | optional |  `[]`  |
| <a id="elide_kotlin_test-data"></a>data |  Files made available to this target's runfiles at action time.   | <a href="https://bazel.build/concepts/labels">List of labels</a> | optional |  `[]`  |
| <a id="elide_kotlin_test-resources"></a>resources |  Resource files packaged into the output JAR alongside compiled classes.   | <a href="https://bazel.build/concepts/labels">List of labels</a> | optional |  `[]`  |
| <a id="elide_kotlin_test-associates"></a>associates |  Targets whose compile jars become Kotlin friend-paths (grants internal visibility).   | <a href="https://bazel.build/concepts/labels">List of labels</a> | optional |  `[]`  |
| <a id="elide_kotlin_test-builtin_plugins"></a>builtin_plugins |  Builtin Kotlin compiler plugins to enable by name via `elide kotlinc --plugins` (e.g. "serialization", "metro", "atomicfu", "power-assert"). Use to force on plugins the classpath heuristic may miss (notably Metro). Note: an explicit suite does not yet fully disable heuristic-detected plugins it omits (WHIPLASH#1119).   | List of strings | optional |  `[]`  |
| <a id="elide_kotlin_test-exported_compiler_plugins"></a>exported_compiler_plugins |  Compiler plugins propagated to direct rdeps via ElideInfo (mirrors java_plugin.exported_plugins).   | <a href="https://bazel.build/concepts/labels">List of labels</a> | optional |  `[]`  |
| <a id="elide_kotlin_test-exports"></a>exports |  Targets re-exported to direct rdeps (transitive compile classpath).   | <a href="https://bazel.build/concepts/labels">List of labels</a> | optional |  `[]`  |
| <a id="elide_kotlin_test-javac_opts"></a>javac_opts |  Flags forwarded to javac through kotlinc (`-Xjavac-arguments=`).   | List of strings | optional |  `[]`  |
| <a id="elide_kotlin_test-jvm_flags"></a>jvm_flags |  Flags passed to the JVM when running the test.   | List of strings | optional |  `[]`  |
| <a id="elide_kotlin_test-kotlinc_opts"></a>kotlinc_opts |  Flags appended to the `elide kotlinc --` invocation.   | List of strings | optional |  `[]`  |
| <a id="elide_kotlin_test-module_name"></a>module_name |  Kotlin module name (`-module-name`).   | String | optional |  `""`  |
| <a id="elide_kotlin_test-neverlink"></a>neverlink |  If true, outputs are used only for compilation, not packaged into binaries.   | Boolean | optional |  `False`  |
| <a id="elide_kotlin_test-plugins"></a>plugins |  Compiler plugins for this compilation (only). Targets must provide JavaInfo.   | <a href="https://bazel.build/concepts/labels">List of labels</a> | optional |  `[]`  |
| <a id="elide_kotlin_test-resource_jars"></a>resource_jars |  Pre-built JARs whose contents are merged into the output JAR.   | <a href="https://bazel.build/concepts/labels">List of labels</a> | optional |  `[]`  |
| <a id="elide_kotlin_test-resource_strip_prefix"></a>resource_strip_prefix |  Workspace-root-relative path prefix stripped from each `resources` entry when computing its in-JAR location (mirrors java_library.resource_strip_prefix). Empty -> use the full short_path.   | String | optional |  `""`  |
| <a id="elide_kotlin_test-runtime_deps"></a>runtime_deps |  Runtime-only dependencies (excluded from compile classpath).   | <a href="https://bazel.build/concepts/labels">List of labels</a> | optional |  `[]`  |
| <a id="elide_kotlin_test-test_class"></a>test_class |  Single JUnit Platform test class to select. Empty -> --scan-classpath.   | String | optional |  `""`  |
