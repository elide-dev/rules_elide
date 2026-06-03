<!-- Generated with Stardoc: http://skydoc.bazel.build -->

Public API entry point for rules_elide.

Downstream users should load all symbols from this file. Internal paths under
`elide/` are not part of the stable API.

<a id="elide_format"></a>

## elide_format

<pre>
load("@rules_elide//elide:defs.bzl", "elide_format")

elide_format(<a href="#elide_format-name">name</a>, <a href="#elide_format-srcs">srcs</a>)
</pre>



**ATTRIBUTES**


| Name  | Description | Type | Mandatory | Default |
| :------------- | :------------- | :------------- | :------------- | :------------- |
| <a id="elide_format-name"></a>name |  A unique name for this target.   | <a href="https://bazel.build/concepts/labels#target-names">Name</a> | required |  |
| <a id="elide_format-srcs"></a>srcs |  Source files to format. All must be .java or all .kt/.kts.   | <a href="https://bazel.build/concepts/labels">List of labels</a> | required |  |


<a id="elide_java_binary"></a>

## elide_java_binary

<pre>
load("@rules_elide//elide:defs.bzl", "elide_java_binary")

elide_java_binary(<a href="#elide_java_binary-name">name</a>, <a href="#elide_java_binary-deps">deps</a>, <a href="#elide_java_binary-srcs">srcs</a>, <a href="#elide_java_binary-data">data</a>, <a href="#elide_java_binary-resources">resources</a>, <a href="#elide_java_binary-exported_compiler_plugins">exported_compiler_plugins</a>, <a href="#elide_java_binary-exports">exports</a>, <a href="#elide_java_binary-javac_opts">javac_opts</a>,
                  <a href="#elide_java_binary-jvm_flags">jvm_flags</a>, <a href="#elide_java_binary-main_class">main_class</a>, <a href="#elide_java_binary-neverlink">neverlink</a>, <a href="#elide_java_binary-plugins">plugins</a>, <a href="#elide_java_binary-resource_jars">resource_jars</a>, <a href="#elide_java_binary-resource_strip_prefix">resource_strip_prefix</a>,
                  <a href="#elide_java_binary-runtime_deps">runtime_deps</a>)
</pre>



**ATTRIBUTES**


| Name  | Description | Type | Mandatory | Default |
| :------------- | :------------- | :------------- | :------------- | :------------- |
| <a id="elide_java_binary-name"></a>name |  A unique name for this target.   | <a href="https://bazel.build/concepts/labels#target-names">Name</a> | required |  |
| <a id="elide_java_binary-deps"></a>deps |  Compile-time dependencies. Targets must provide JavaInfo.   | <a href="https://bazel.build/concepts/labels">List of labels</a> | optional |  `[]`  |
| <a id="elide_java_binary-srcs"></a>srcs |  Java source files to compile.   | <a href="https://bazel.build/concepts/labels">List of labels</a> | optional |  `[]`  |
| <a id="elide_java_binary-data"></a>data |  Files made available to this target's runfiles at action time.   | <a href="https://bazel.build/concepts/labels">List of labels</a> | optional |  `[]`  |
| <a id="elide_java_binary-resources"></a>resources |  Resource files packaged into the output JAR alongside compiled classes.   | <a href="https://bazel.build/concepts/labels">List of labels</a> | optional |  `[]`  |
| <a id="elide_java_binary-exported_compiler_plugins"></a>exported_compiler_plugins |  Compiler plugins propagated to direct rdeps via ElideInfo (mirrors java_plugin.exported_plugins).   | <a href="https://bazel.build/concepts/labels">List of labels</a> | optional |  `[]`  |
| <a id="elide_java_binary-exports"></a>exports |  Targets re-exported to direct rdeps (transitive compile classpath).   | <a href="https://bazel.build/concepts/labels">List of labels</a> | optional |  `[]`  |
| <a id="elide_java_binary-javac_opts"></a>javac_opts |  Flags appended to the `elide javac --` invocation.   | List of strings | optional |  `[]`  |
| <a id="elide_java_binary-jvm_flags"></a>jvm_flags |  Flags passed to the JVM when running the binary.   | List of strings | optional |  `[]`  |
| <a id="elide_java_binary-main_class"></a>main_class |  Fully qualified main class.   | String | required |  |
| <a id="elide_java_binary-neverlink"></a>neverlink |  If true, outputs are used only for compilation, not packaged into binaries.   | Boolean | optional |  `False`  |
| <a id="elide_java_binary-plugins"></a>plugins |  Compiler plugins for this compilation (only). Targets must provide JavaInfo.   | <a href="https://bazel.build/concepts/labels">List of labels</a> | optional |  `[]`  |
| <a id="elide_java_binary-resource_jars"></a>resource_jars |  Pre-built JARs whose contents are merged into the output JAR.   | <a href="https://bazel.build/concepts/labels">List of labels</a> | optional |  `[]`  |
| <a id="elide_java_binary-resource_strip_prefix"></a>resource_strip_prefix |  Workspace-root-relative path prefix stripped from each `resources` entry when computing its in-JAR location (mirrors java_library.resource_strip_prefix). Empty -> use the full short_path.   | String | optional |  `""`  |
| <a id="elide_java_binary-runtime_deps"></a>runtime_deps |  Runtime-only dependencies (excluded from compile classpath).   | <a href="https://bazel.build/concepts/labels">List of labels</a> | optional |  `[]`  |


<a id="elide_java_library"></a>

## elide_java_library

<pre>
load("@rules_elide//elide:defs.bzl", "elide_java_library")

elide_java_library(<a href="#elide_java_library-name">name</a>, <a href="#elide_java_library-deps">deps</a>, <a href="#elide_java_library-srcs">srcs</a>, <a href="#elide_java_library-data">data</a>, <a href="#elide_java_library-resources">resources</a>, <a href="#elide_java_library-exported_compiler_plugins">exported_compiler_plugins</a>, <a href="#elide_java_library-exports">exports</a>,
                   <a href="#elide_java_library-javac_opts">javac_opts</a>, <a href="#elide_java_library-neverlink">neverlink</a>, <a href="#elide_java_library-plugins">plugins</a>, <a href="#elide_java_library-resource_jars">resource_jars</a>, <a href="#elide_java_library-resource_strip_prefix">resource_strip_prefix</a>, <a href="#elide_java_library-runtime_deps">runtime_deps</a>)
</pre>



**ATTRIBUTES**


| Name  | Description | Type | Mandatory | Default |
| :------------- | :------------- | :------------- | :------------- | :------------- |
| <a id="elide_java_library-name"></a>name |  A unique name for this target.   | <a href="https://bazel.build/concepts/labels#target-names">Name</a> | required |  |
| <a id="elide_java_library-deps"></a>deps |  Compile-time dependencies. Targets must provide JavaInfo.   | <a href="https://bazel.build/concepts/labels">List of labels</a> | optional |  `[]`  |
| <a id="elide_java_library-srcs"></a>srcs |  Java source files to compile.   | <a href="https://bazel.build/concepts/labels">List of labels</a> | optional |  `[]`  |
| <a id="elide_java_library-data"></a>data |  Files made available to this target's runfiles at action time.   | <a href="https://bazel.build/concepts/labels">List of labels</a> | optional |  `[]`  |
| <a id="elide_java_library-resources"></a>resources |  Resource files packaged into the output JAR alongside compiled classes.   | <a href="https://bazel.build/concepts/labels">List of labels</a> | optional |  `[]`  |
| <a id="elide_java_library-exported_compiler_plugins"></a>exported_compiler_plugins |  Compiler plugins propagated to direct rdeps via ElideInfo (mirrors java_plugin.exported_plugins).   | <a href="https://bazel.build/concepts/labels">List of labels</a> | optional |  `[]`  |
| <a id="elide_java_library-exports"></a>exports |  Targets re-exported to direct rdeps (transitive compile classpath).   | <a href="https://bazel.build/concepts/labels">List of labels</a> | optional |  `[]`  |
| <a id="elide_java_library-javac_opts"></a>javac_opts |  Flags appended to the `elide javac --` invocation.   | List of strings | optional |  `[]`  |
| <a id="elide_java_library-neverlink"></a>neverlink |  If true, outputs are used only for compilation, not packaged into binaries.   | Boolean | optional |  `False`  |
| <a id="elide_java_library-plugins"></a>plugins |  Compiler plugins for this compilation (only). Targets must provide JavaInfo.   | <a href="https://bazel.build/concepts/labels">List of labels</a> | optional |  `[]`  |
| <a id="elide_java_library-resource_jars"></a>resource_jars |  Pre-built JARs whose contents are merged into the output JAR.   | <a href="https://bazel.build/concepts/labels">List of labels</a> | optional |  `[]`  |
| <a id="elide_java_library-resource_strip_prefix"></a>resource_strip_prefix |  Workspace-root-relative path prefix stripped from each `resources` entry when computing its in-JAR location (mirrors java_library.resource_strip_prefix). Empty -> use the full short_path.   | String | optional |  `""`  |
| <a id="elide_java_library-runtime_deps"></a>runtime_deps |  Runtime-only dependencies (excluded from compile classpath).   | <a href="https://bazel.build/concepts/labels">List of labels</a> | optional |  `[]`  |


<a id="elide_java_test"></a>

## elide_java_test

<pre>
load("@rules_elide//elide:defs.bzl", "elide_java_test")

elide_java_test(<a href="#elide_java_test-name">name</a>, <a href="#elide_java_test-deps">deps</a>, <a href="#elide_java_test-srcs">srcs</a>, <a href="#elide_java_test-data">data</a>, <a href="#elide_java_test-resources">resources</a>, <a href="#elide_java_test-exported_compiler_plugins">exported_compiler_plugins</a>, <a href="#elide_java_test-exports">exports</a>, <a href="#elide_java_test-javac_opts">javac_opts</a>,
                <a href="#elide_java_test-jvm_flags">jvm_flags</a>, <a href="#elide_java_test-neverlink">neverlink</a>, <a href="#elide_java_test-plugins">plugins</a>, <a href="#elide_java_test-resource_jars">resource_jars</a>, <a href="#elide_java_test-resource_strip_prefix">resource_strip_prefix</a>, <a href="#elide_java_test-runtime_deps">runtime_deps</a>,
                <a href="#elide_java_test-test_class">test_class</a>)
</pre>



**ATTRIBUTES**


| Name  | Description | Type | Mandatory | Default |
| :------------- | :------------- | :------------- | :------------- | :------------- |
| <a id="elide_java_test-name"></a>name |  A unique name for this target.   | <a href="https://bazel.build/concepts/labels#target-names">Name</a> | required |  |
| <a id="elide_java_test-deps"></a>deps |  Compile-time dependencies. Targets must provide JavaInfo.   | <a href="https://bazel.build/concepts/labels">List of labels</a> | optional |  `[]`  |
| <a id="elide_java_test-srcs"></a>srcs |  Java source files to compile.   | <a href="https://bazel.build/concepts/labels">List of labels</a> | optional |  `[]`  |
| <a id="elide_java_test-data"></a>data |  Files made available to this target's runfiles at action time.   | <a href="https://bazel.build/concepts/labels">List of labels</a> | optional |  `[]`  |
| <a id="elide_java_test-resources"></a>resources |  Resource files packaged into the output JAR alongside compiled classes.   | <a href="https://bazel.build/concepts/labels">List of labels</a> | optional |  `[]`  |
| <a id="elide_java_test-exported_compiler_plugins"></a>exported_compiler_plugins |  Compiler plugins propagated to direct rdeps via ElideInfo (mirrors java_plugin.exported_plugins).   | <a href="https://bazel.build/concepts/labels">List of labels</a> | optional |  `[]`  |
| <a id="elide_java_test-exports"></a>exports |  Targets re-exported to direct rdeps (transitive compile classpath).   | <a href="https://bazel.build/concepts/labels">List of labels</a> | optional |  `[]`  |
| <a id="elide_java_test-javac_opts"></a>javac_opts |  Flags appended to the `elide javac --` invocation.   | List of strings | optional |  `[]`  |
| <a id="elide_java_test-jvm_flags"></a>jvm_flags |  Flags passed to the JVM when running the test.   | List of strings | optional |  `[]`  |
| <a id="elide_java_test-neverlink"></a>neverlink |  If true, outputs are used only for compilation, not packaged into binaries.   | Boolean | optional |  `False`  |
| <a id="elide_java_test-plugins"></a>plugins |  Compiler plugins for this compilation (only). Targets must provide JavaInfo.   | <a href="https://bazel.build/concepts/labels">List of labels</a> | optional |  `[]`  |
| <a id="elide_java_test-resource_jars"></a>resource_jars |  Pre-built JARs whose contents are merged into the output JAR.   | <a href="https://bazel.build/concepts/labels">List of labels</a> | optional |  `[]`  |
| <a id="elide_java_test-resource_strip_prefix"></a>resource_strip_prefix |  Workspace-root-relative path prefix stripped from each `resources` entry when computing its in-JAR location (mirrors java_library.resource_strip_prefix). Empty -> use the full short_path.   | String | optional |  `""`  |
| <a id="elide_java_test-runtime_deps"></a>runtime_deps |  Runtime-only dependencies (excluded from compile classpath).   | <a href="https://bazel.build/concepts/labels">List of labels</a> | optional |  `[]`  |
| <a id="elide_java_test-test_class"></a>test_class |  Single JUnit Platform test class to select. Empty -> --scan-classpath.   | String | optional |  `""`  |


<a id="elide_kotlin_binary"></a>

## elide_kotlin_binary

<pre>
load("@rules_elide//elide:defs.bzl", "elide_kotlin_binary")

elide_kotlin_binary(<a href="#elide_kotlin_binary-name">name</a>, <a href="#elide_kotlin_binary-deps">deps</a>, <a href="#elide_kotlin_binary-srcs">srcs</a>, <a href="#elide_kotlin_binary-data">data</a>, <a href="#elide_kotlin_binary-resources">resources</a>, <a href="#elide_kotlin_binary-associates">associates</a>, <a href="#elide_kotlin_binary-exported_compiler_plugins">exported_compiler_plugins</a>,
                    <a href="#elide_kotlin_binary-exports">exports</a>, <a href="#elide_kotlin_binary-javac_opts">javac_opts</a>, <a href="#elide_kotlin_binary-jvm_flags">jvm_flags</a>, <a href="#elide_kotlin_binary-kotlinc_opts">kotlinc_opts</a>, <a href="#elide_kotlin_binary-main_class">main_class</a>, <a href="#elide_kotlin_binary-module_name">module_name</a>, <a href="#elide_kotlin_binary-neverlink">neverlink</a>,
                    <a href="#elide_kotlin_binary-plugins">plugins</a>, <a href="#elide_kotlin_binary-resource_jars">resource_jars</a>, <a href="#elide_kotlin_binary-resource_strip_prefix">resource_strip_prefix</a>, <a href="#elide_kotlin_binary-runtime_deps">runtime_deps</a>)
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
load("@rules_elide//elide:defs.bzl", "elide_kotlin_library")

elide_kotlin_library(<a href="#elide_kotlin_library-name">name</a>, <a href="#elide_kotlin_library-deps">deps</a>, <a href="#elide_kotlin_library-srcs">srcs</a>, <a href="#elide_kotlin_library-data">data</a>, <a href="#elide_kotlin_library-resources">resources</a>, <a href="#elide_kotlin_library-associates">associates</a>, <a href="#elide_kotlin_library-exported_compiler_plugins">exported_compiler_plugins</a>,
                     <a href="#elide_kotlin_library-exports">exports</a>, <a href="#elide_kotlin_library-javac_opts">javac_opts</a>, <a href="#elide_kotlin_library-kotlinc_opts">kotlinc_opts</a>, <a href="#elide_kotlin_library-module_name">module_name</a>, <a href="#elide_kotlin_library-neverlink">neverlink</a>, <a href="#elide_kotlin_library-plugins">plugins</a>,
                     <a href="#elide_kotlin_library-resource_jars">resource_jars</a>, <a href="#elide_kotlin_library-resource_strip_prefix">resource_strip_prefix</a>, <a href="#elide_kotlin_library-runtime_deps">runtime_deps</a>)
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
load("@rules_elide//elide:defs.bzl", "elide_kotlin_test")

elide_kotlin_test(<a href="#elide_kotlin_test-name">name</a>, <a href="#elide_kotlin_test-deps">deps</a>, <a href="#elide_kotlin_test-srcs">srcs</a>, <a href="#elide_kotlin_test-data">data</a>, <a href="#elide_kotlin_test-resources">resources</a>, <a href="#elide_kotlin_test-associates">associates</a>, <a href="#elide_kotlin_test-exported_compiler_plugins">exported_compiler_plugins</a>, <a href="#elide_kotlin_test-exports">exports</a>,
                  <a href="#elide_kotlin_test-javac_opts">javac_opts</a>, <a href="#elide_kotlin_test-jvm_flags">jvm_flags</a>, <a href="#elide_kotlin_test-kotlinc_opts">kotlinc_opts</a>, <a href="#elide_kotlin_test-module_name">module_name</a>, <a href="#elide_kotlin_test-neverlink">neverlink</a>, <a href="#elide_kotlin_test-plugins">plugins</a>, <a href="#elide_kotlin_test-resource_jars">resource_jars</a>,
                  <a href="#elide_kotlin_test-resource_strip_prefix">resource_strip_prefix</a>, <a href="#elide_kotlin_test-runtime_deps">runtime_deps</a>, <a href="#elide_kotlin_test-test_class">test_class</a>)
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


<a id="elide_native_image"></a>

## elide_native_image

<pre>
load("@rules_elide//elide:defs.bzl", "elide_native_image")

elide_native_image(<a href="#elide_native_image-name">name</a>, <a href="#elide_native_image-deps">deps</a>, <a href="#elide_native_image-main_class">main_class</a>, <a href="#elide_native_image-native_image_opts">native_image_opts</a>)
</pre>



**ATTRIBUTES**


| Name  | Description | Type | Mandatory | Default |
| :------------- | :------------- | :------------- | :------------- | :------------- |
| <a id="elide_native_image-name"></a>name |  A unique name for this target.   | <a href="https://bazel.build/concepts/labels#target-names">Name</a> | required |  |
| <a id="elide_native_image-deps"></a>deps |  JVM dependencies whose runtime classpath enters the native image.   | <a href="https://bazel.build/concepts/labels">List of labels</a> | optional |  `[]`  |
| <a id="elide_native_image-main_class"></a>main_class |  Fully qualified main class.   | String | required |  |
| <a id="elide_native_image-native_image_opts"></a>native_image_opts |  Extra flags appended to the native-image invocation.   | List of strings | optional |  `[]`  |


<a id="elide_toolchain"></a>

## elide_toolchain

<pre>
load("@rules_elide//elide:defs.bzl", "elide_toolchain")

elide_toolchain(<a href="#elide_toolchain-name">name</a>, <a href="#elide_toolchain-binary">binary</a>, <a href="#elide_toolchain-compile_tool_files">compile_tool_files</a>, <a href="#elide_toolchain-kotlin_stdlib">kotlin_stdlib</a>, <a href="#elide_toolchain-tool_files">tool_files</a>, <a href="#elide_toolchain-version">version</a>)
</pre>



**ATTRIBUTES**


| Name  | Description | Type | Mandatory | Default |
| :------------- | :------------- | :------------- | :------------- | :------------- |
| <a id="elide_toolchain-name"></a>name |  A unique name for this target.   | <a href="https://bazel.build/concepts/labels#target-names">Name</a> | required |  |
| <a id="elide_toolchain-binary"></a>binary |  Executable target for the elide binary.   | <a href="https://bazel.build/concepts/labels">Label</a> | required |  |
| <a id="elide_toolchain-compile_tool_files"></a>compile_tool_files |  Inputs for JVM compile actions (javac, kotlinc, jar). Should reference the elide_compile_files filegroup.   | <a href="https://bazel.build/concepts/labels">List of labels</a> | optional |  `[]`  |
| <a id="elide_toolchain-kotlin_stdlib"></a>kotlin_stdlib |  Kotlin stdlib jars bundled with this Elide release (from kotlin_stdlib_jars filegroup).   | <a href="https://bazel.build/concepts/labels">List of labels</a> | optional |  `[]`  |
| <a id="elide_toolchain-tool_files"></a>tool_files |  Inputs for native-image actions (includes lib/svm, include/). Should reference the elide_native_image_files filegroup.   | <a href="https://bazel.build/concepts/labels">List of labels</a> | optional |  `[]`  |
| <a id="elide_toolchain-version"></a>version |  Semantic version of the elide binary.   | String | required |  |


<a id="ElideInfo"></a>

## ElideInfo

<pre>
load("@rules_elide//elide:defs.bzl", "ElideInfo")

ElideInfo(<a href="#ElideInfo-exported_compiler_plugins">exported_compiler_plugins</a>, <a href="#ElideInfo-manifest">manifest</a>)
</pre>

Elide-specific metadata emitted by rules_elide build rules.

**FIELDS**

| Name  | Description |
| :------------- | :------------- |
| <a id="ElideInfo-exported_compiler_plugins"></a>exported_compiler_plugins |  depset[Target]. Compiler plugins propagated to direct rdeps. Mirrors java_plugin's exported_plugins.    |
| <a id="ElideInfo-manifest"></a>manifest |  File or None. Optional elide.pkl-style project manifest.    |


<a id="ElideToolchainInfo"></a>

## ElideToolchainInfo

<pre>
load("@rules_elide//elide:defs.bzl", "ElideToolchainInfo")

ElideToolchainInfo(<a href="#ElideToolchainInfo-binary">binary</a>, <a href="#ElideToolchainInfo-compile_tool_files">compile_tool_files</a>, <a href="#ElideToolchainInfo-kotlin_stdlib_jars">kotlin_stdlib_jars</a>, <a href="#ElideToolchainInfo-tool_files">tool_files</a>, <a href="#ElideToolchainInfo-version">version</a>)
</pre>

Resolved Elide toolchain information.

**FIELDS**

| Name  | Description |
| :------------- | :------------- |
| <a id="ElideToolchainInfo-binary"></a>binary |  File. The elide binary executable.    |
| <a id="ElideToolchainInfo-compile_tool_files"></a>compile_tool_files |  depset[File]. Inputs for JVM compile actions (javac, kotlinc, jar). Excludes native-image-only subtrees (lib/svm, lib/truffle, doc).    |
| <a id="ElideToolchainInfo-kotlin_stdlib_jars"></a>kotlin_stdlib_jars |  depset[File]. Kotlin stdlib jar(s) bundled with this Elide release.    |
| <a id="ElideToolchainInfo-tool_files"></a>tool_files |  depset[File]. Inputs for native-image actions (includes lib/svm, include/).    |
| <a id="ElideToolchainInfo-version"></a>version |  string. Semantic version of the elide binary.    |
