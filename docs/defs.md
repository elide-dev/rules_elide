<!-- Generated with Stardoc: http://skydoc.bazel.build -->

Public API entry point for rules_elide.

Downstream users should load all symbols from this file. Internal paths under
`elide/` are not part of the stable API.

<a id="elide_java_binary"></a>

## elide_java_binary

<pre>
load("@rules_elide//elide:defs.bzl", "elide_java_binary")

elide_java_binary(<a href="#elide_java_binary-name">name</a>, <a href="#elide_java_binary-deps">deps</a>, <a href="#elide_java_binary-srcs">srcs</a>, <a href="#elide_java_binary-exported_compiler_plugins">exported_compiler_plugins</a>, <a href="#elide_java_binary-exports">exports</a>, <a href="#elide_java_binary-javac_opts">javac_opts</a>, <a href="#elide_java_binary-jvm_flags">jvm_flags</a>,
                  <a href="#elide_java_binary-main_class">main_class</a>, <a href="#elide_java_binary-neverlink">neverlink</a>, <a href="#elide_java_binary-runtime_deps">runtime_deps</a>)
</pre>



**ATTRIBUTES**


| Name  | Description | Type | Mandatory | Default |
| :------------- | :------------- | :------------- | :------------- | :------------- |
| <a id="elide_java_binary-name"></a>name |  A unique name for this target.   | <a href="https://bazel.build/concepts/labels#target-names">Name</a> | required |  |
| <a id="elide_java_binary-deps"></a>deps |  -   | <a href="https://bazel.build/concepts/labels">List of labels</a> | optional |  `[]`  |
| <a id="elide_java_binary-srcs"></a>srcs |  -   | <a href="https://bazel.build/concepts/labels">List of labels</a> | optional |  `[]`  |
| <a id="elide_java_binary-exported_compiler_plugins"></a>exported_compiler_plugins |  -   | <a href="https://bazel.build/concepts/labels">List of labels</a> | optional |  `[]`  |
| <a id="elide_java_binary-exports"></a>exports |  -   | <a href="https://bazel.build/concepts/labels">List of labels</a> | optional |  `[]`  |
| <a id="elide_java_binary-javac_opts"></a>javac_opts |  -   | List of strings | optional |  `[]`  |
| <a id="elide_java_binary-jvm_flags"></a>jvm_flags |  -   | List of strings | optional |  `[]`  |
| <a id="elide_java_binary-main_class"></a>main_class |  -   | String | required |  |
| <a id="elide_java_binary-neverlink"></a>neverlink |  -   | Boolean | optional |  `False`  |
| <a id="elide_java_binary-runtime_deps"></a>runtime_deps |  -   | <a href="https://bazel.build/concepts/labels">List of labels</a> | optional |  `[]`  |


<a id="elide_java_library"></a>

## elide_java_library

<pre>
load("@rules_elide//elide:defs.bzl", "elide_java_library")

elide_java_library(<a href="#elide_java_library-name">name</a>, <a href="#elide_java_library-deps">deps</a>, <a href="#elide_java_library-srcs">srcs</a>, <a href="#elide_java_library-exported_compiler_plugins">exported_compiler_plugins</a>, <a href="#elide_java_library-exports">exports</a>, <a href="#elide_java_library-javac_opts">javac_opts</a>, <a href="#elide_java_library-neverlink">neverlink</a>,
                   <a href="#elide_java_library-runtime_deps">runtime_deps</a>)
</pre>



**ATTRIBUTES**


| Name  | Description | Type | Mandatory | Default |
| :------------- | :------------- | :------------- | :------------- | :------------- |
| <a id="elide_java_library-name"></a>name |  A unique name for this target.   | <a href="https://bazel.build/concepts/labels#target-names">Name</a> | required |  |
| <a id="elide_java_library-deps"></a>deps |  -   | <a href="https://bazel.build/concepts/labels">List of labels</a> | optional |  `[]`  |
| <a id="elide_java_library-srcs"></a>srcs |  -   | <a href="https://bazel.build/concepts/labels">List of labels</a> | optional |  `[]`  |
| <a id="elide_java_library-exported_compiler_plugins"></a>exported_compiler_plugins |  -   | <a href="https://bazel.build/concepts/labels">List of labels</a> | optional |  `[]`  |
| <a id="elide_java_library-exports"></a>exports |  -   | <a href="https://bazel.build/concepts/labels">List of labels</a> | optional |  `[]`  |
| <a id="elide_java_library-javac_opts"></a>javac_opts |  -   | List of strings | optional |  `[]`  |
| <a id="elide_java_library-neverlink"></a>neverlink |  -   | Boolean | optional |  `False`  |
| <a id="elide_java_library-runtime_deps"></a>runtime_deps |  -   | <a href="https://bazel.build/concepts/labels">List of labels</a> | optional |  `[]`  |


<a id="elide_java_test"></a>

## elide_java_test

<pre>
load("@rules_elide//elide:defs.bzl", "elide_java_test")

elide_java_test(<a href="#elide_java_test-name">name</a>, <a href="#elide_java_test-deps">deps</a>, <a href="#elide_java_test-srcs">srcs</a>, <a href="#elide_java_test-exported_compiler_plugins">exported_compiler_plugins</a>, <a href="#elide_java_test-exports">exports</a>, <a href="#elide_java_test-javac_opts">javac_opts</a>, <a href="#elide_java_test-jvm_flags">jvm_flags</a>,
                <a href="#elide_java_test-neverlink">neverlink</a>, <a href="#elide_java_test-runtime_deps">runtime_deps</a>, <a href="#elide_java_test-test_class">test_class</a>)
</pre>



**ATTRIBUTES**


| Name  | Description | Type | Mandatory | Default |
| :------------- | :------------- | :------------- | :------------- | :------------- |
| <a id="elide_java_test-name"></a>name |  A unique name for this target.   | <a href="https://bazel.build/concepts/labels#target-names">Name</a> | required |  |
| <a id="elide_java_test-deps"></a>deps |  -   | <a href="https://bazel.build/concepts/labels">List of labels</a> | optional |  `[]`  |
| <a id="elide_java_test-srcs"></a>srcs |  -   | <a href="https://bazel.build/concepts/labels">List of labels</a> | optional |  `[]`  |
| <a id="elide_java_test-exported_compiler_plugins"></a>exported_compiler_plugins |  -   | <a href="https://bazel.build/concepts/labels">List of labels</a> | optional |  `[]`  |
| <a id="elide_java_test-exports"></a>exports |  -   | <a href="https://bazel.build/concepts/labels">List of labels</a> | optional |  `[]`  |
| <a id="elide_java_test-javac_opts"></a>javac_opts |  -   | List of strings | optional |  `[]`  |
| <a id="elide_java_test-jvm_flags"></a>jvm_flags |  -   | List of strings | optional |  `[]`  |
| <a id="elide_java_test-neverlink"></a>neverlink |  -   | Boolean | optional |  `False`  |
| <a id="elide_java_test-runtime_deps"></a>runtime_deps |  -   | <a href="https://bazel.build/concepts/labels">List of labels</a> | optional |  `[]`  |
| <a id="elide_java_test-test_class"></a>test_class |  Single JUnit Platform test class to select. When unset, the runner scans the classpath.   | String | optional |  `""`  |


<a id="elide_kotlin_binary"></a>

## elide_kotlin_binary

<pre>
load("@rules_elide//elide:defs.bzl", "elide_kotlin_binary")

elide_kotlin_binary(<a href="#elide_kotlin_binary-name">name</a>, <a href="#elide_kotlin_binary-deps">deps</a>, <a href="#elide_kotlin_binary-srcs">srcs</a>, <a href="#elide_kotlin_binary-exported_compiler_plugins">exported_compiler_plugins</a>, <a href="#elide_kotlin_binary-exports">exports</a>, <a href="#elide_kotlin_binary-javac_opts">javac_opts</a>, <a href="#elide_kotlin_binary-jvm_flags">jvm_flags</a>,
                    <a href="#elide_kotlin_binary-kotlinc_opts">kotlinc_opts</a>, <a href="#elide_kotlin_binary-main_class">main_class</a>, <a href="#elide_kotlin_binary-module_name">module_name</a>, <a href="#elide_kotlin_binary-neverlink">neverlink</a>, <a href="#elide_kotlin_binary-runtime_deps">runtime_deps</a>)
</pre>



**ATTRIBUTES**


| Name  | Description | Type | Mandatory | Default |
| :------------- | :------------- | :------------- | :------------- | :------------- |
| <a id="elide_kotlin_binary-name"></a>name |  A unique name for this target.   | <a href="https://bazel.build/concepts/labels#target-names">Name</a> | required |  |
| <a id="elide_kotlin_binary-deps"></a>deps |  -   | <a href="https://bazel.build/concepts/labels">List of labels</a> | optional |  `[]`  |
| <a id="elide_kotlin_binary-srcs"></a>srcs |  -   | <a href="https://bazel.build/concepts/labels">List of labels</a> | optional |  `[]`  |
| <a id="elide_kotlin_binary-exported_compiler_plugins"></a>exported_compiler_plugins |  -   | <a href="https://bazel.build/concepts/labels">List of labels</a> | optional |  `[]`  |
| <a id="elide_kotlin_binary-exports"></a>exports |  -   | <a href="https://bazel.build/concepts/labels">List of labels</a> | optional |  `[]`  |
| <a id="elide_kotlin_binary-javac_opts"></a>javac_opts |  -   | List of strings | optional |  `[]`  |
| <a id="elide_kotlin_binary-jvm_flags"></a>jvm_flags |  -   | List of strings | optional |  `[]`  |
| <a id="elide_kotlin_binary-kotlinc_opts"></a>kotlinc_opts |  -   | List of strings | optional |  `[]`  |
| <a id="elide_kotlin_binary-main_class"></a>main_class |  -   | String | required |  |
| <a id="elide_kotlin_binary-module_name"></a>module_name |  -   | String | optional |  `""`  |
| <a id="elide_kotlin_binary-neverlink"></a>neverlink |  -   | Boolean | optional |  `False`  |
| <a id="elide_kotlin_binary-runtime_deps"></a>runtime_deps |  -   | <a href="https://bazel.build/concepts/labels">List of labels</a> | optional |  `[]`  |


<a id="elide_kotlin_library"></a>

## elide_kotlin_library

<pre>
load("@rules_elide//elide:defs.bzl", "elide_kotlin_library")

elide_kotlin_library(<a href="#elide_kotlin_library-name">name</a>, <a href="#elide_kotlin_library-deps">deps</a>, <a href="#elide_kotlin_library-srcs">srcs</a>, <a href="#elide_kotlin_library-exported_compiler_plugins">exported_compiler_plugins</a>, <a href="#elide_kotlin_library-exports">exports</a>, <a href="#elide_kotlin_library-javac_opts">javac_opts</a>, <a href="#elide_kotlin_library-kotlinc_opts">kotlinc_opts</a>,
                     <a href="#elide_kotlin_library-module_name">module_name</a>, <a href="#elide_kotlin_library-neverlink">neverlink</a>, <a href="#elide_kotlin_library-runtime_deps">runtime_deps</a>)
</pre>



**ATTRIBUTES**


| Name  | Description | Type | Mandatory | Default |
| :------------- | :------------- | :------------- | :------------- | :------------- |
| <a id="elide_kotlin_library-name"></a>name |  A unique name for this target.   | <a href="https://bazel.build/concepts/labels#target-names">Name</a> | required |  |
| <a id="elide_kotlin_library-deps"></a>deps |  -   | <a href="https://bazel.build/concepts/labels">List of labels</a> | optional |  `[]`  |
| <a id="elide_kotlin_library-srcs"></a>srcs |  -   | <a href="https://bazel.build/concepts/labels">List of labels</a> | optional |  `[]`  |
| <a id="elide_kotlin_library-exported_compiler_plugins"></a>exported_compiler_plugins |  -   | <a href="https://bazel.build/concepts/labels">List of labels</a> | optional |  `[]`  |
| <a id="elide_kotlin_library-exports"></a>exports |  -   | <a href="https://bazel.build/concepts/labels">List of labels</a> | optional |  `[]`  |
| <a id="elide_kotlin_library-javac_opts"></a>javac_opts |  -   | List of strings | optional |  `[]`  |
| <a id="elide_kotlin_library-kotlinc_opts"></a>kotlinc_opts |  -   | List of strings | optional |  `[]`  |
| <a id="elide_kotlin_library-module_name"></a>module_name |  -   | String | optional |  `""`  |
| <a id="elide_kotlin_library-neverlink"></a>neverlink |  -   | Boolean | optional |  `False`  |
| <a id="elide_kotlin_library-runtime_deps"></a>runtime_deps |  -   | <a href="https://bazel.build/concepts/labels">List of labels</a> | optional |  `[]`  |


<a id="elide_kotlin_test"></a>

## elide_kotlin_test

<pre>
load("@rules_elide//elide:defs.bzl", "elide_kotlin_test")

elide_kotlin_test(<a href="#elide_kotlin_test-name">name</a>, <a href="#elide_kotlin_test-deps">deps</a>, <a href="#elide_kotlin_test-srcs">srcs</a>, <a href="#elide_kotlin_test-exported_compiler_plugins">exported_compiler_plugins</a>, <a href="#elide_kotlin_test-exports">exports</a>, <a href="#elide_kotlin_test-javac_opts">javac_opts</a>, <a href="#elide_kotlin_test-jvm_flags">jvm_flags</a>,
                  <a href="#elide_kotlin_test-kotlinc_opts">kotlinc_opts</a>, <a href="#elide_kotlin_test-module_name">module_name</a>, <a href="#elide_kotlin_test-neverlink">neverlink</a>, <a href="#elide_kotlin_test-runtime_deps">runtime_deps</a>, <a href="#elide_kotlin_test-test_class">test_class</a>)
</pre>



**ATTRIBUTES**


| Name  | Description | Type | Mandatory | Default |
| :------------- | :------------- | :------------- | :------------- | :------------- |
| <a id="elide_kotlin_test-name"></a>name |  A unique name for this target.   | <a href="https://bazel.build/concepts/labels#target-names">Name</a> | required |  |
| <a id="elide_kotlin_test-deps"></a>deps |  -   | <a href="https://bazel.build/concepts/labels">List of labels</a> | optional |  `[]`  |
| <a id="elide_kotlin_test-srcs"></a>srcs |  -   | <a href="https://bazel.build/concepts/labels">List of labels</a> | optional |  `[]`  |
| <a id="elide_kotlin_test-exported_compiler_plugins"></a>exported_compiler_plugins |  -   | <a href="https://bazel.build/concepts/labels">List of labels</a> | optional |  `[]`  |
| <a id="elide_kotlin_test-exports"></a>exports |  -   | <a href="https://bazel.build/concepts/labels">List of labels</a> | optional |  `[]`  |
| <a id="elide_kotlin_test-javac_opts"></a>javac_opts |  -   | List of strings | optional |  `[]`  |
| <a id="elide_kotlin_test-jvm_flags"></a>jvm_flags |  -   | List of strings | optional |  `[]`  |
| <a id="elide_kotlin_test-kotlinc_opts"></a>kotlinc_opts |  -   | List of strings | optional |  `[]`  |
| <a id="elide_kotlin_test-module_name"></a>module_name |  -   | String | optional |  `""`  |
| <a id="elide_kotlin_test-neverlink"></a>neverlink |  -   | Boolean | optional |  `False`  |
| <a id="elide_kotlin_test-runtime_deps"></a>runtime_deps |  -   | <a href="https://bazel.build/concepts/labels">List of labels</a> | optional |  `[]`  |
| <a id="elide_kotlin_test-test_class"></a>test_class |  Single JUnit Platform test class to select. When unset, the runner scans the classpath.   | String | optional |  `""`  |


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
| <a id="elide_native_image-native_image_opts"></a>native_image_opts |  Extra flags appended to the elide native-image invocation.   | List of strings | optional |  `[]`  |


<a id="elide_toolchain"></a>

## elide_toolchain

<pre>
load("@rules_elide//elide:defs.bzl", "elide_toolchain")

elide_toolchain(<a href="#elide_toolchain-name">name</a>, <a href="#elide_toolchain-binary">binary</a>, <a href="#elide_toolchain-tool_files">tool_files</a>, <a href="#elide_toolchain-version">version</a>)
</pre>



**ATTRIBUTES**


| Name  | Description | Type | Mandatory | Default |
| :------------- | :------------- | :------------- | :------------- | :------------- |
| <a id="elide_toolchain-name"></a>name |  A unique name for this target.   | <a href="https://bazel.build/concepts/labels#target-names">Name</a> | required |  |
| <a id="elide_toolchain-binary"></a>binary |  Executable target for the elide binary.   | <a href="https://bazel.build/concepts/labels">Label</a> | required |  |
| <a id="elide_toolchain-tool_files"></a>tool_files |  Additional runfiles required by the elide binary at action time.   | <a href="https://bazel.build/concepts/labels">List of labels</a> | optional |  `[]`  |
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

ElideToolchainInfo(<a href="#ElideToolchainInfo-binary">binary</a>, <a href="#ElideToolchainInfo-tool_files">tool_files</a>, <a href="#ElideToolchainInfo-version">version</a>)
</pre>

Resolved Elide toolchain information.

**FIELDS**

| Name  | Description |
| :------------- | :------------- |
| <a id="ElideToolchainInfo-binary"></a>binary |  File. The elide binary executable.    |
| <a id="ElideToolchainInfo-tool_files"></a>tool_files |  depset[File]. All runfiles required to invoke elide.    |
| <a id="ElideToolchainInfo-version"></a>version |  string. Semantic version of the elide binary.    |
