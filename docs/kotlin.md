<!-- Generated with Stardoc: http://skydoc.bazel.build -->

Kotlin compile rules for rules_elide.

`elide_kotlin_library` and `elide_kotlin_binary` invoke the Elide CLI to
compile mixed `.kt` / `.java` sources. Both return JavaInfo for seamless
interop with `rules_java` / `rules_kotlin` consumers, plus an ElideInfo for
Elide-specific metadata propagation.

<a id="elide_kotlin_binary"></a>

## elide_kotlin_binary

<pre>
load("@rules_elide//elide/rules:kotlin.bzl", "elide_kotlin_binary")

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
load("@rules_elide//elide/rules:kotlin.bzl", "elide_kotlin_library")

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
load("@rules_elide//elide/rules:kotlin.bzl", "elide_kotlin_test")

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
