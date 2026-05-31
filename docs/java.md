<!-- Generated with Stardoc: http://skydoc.bazel.build -->

Java compile rules for rules_elide.

`elide_java_library` / `_binary` / `_test` drive `elide javac` to compile
`.java` sources. Every rule returns `JavaInfo` (with an `ijar`-derived
`compile_jar` and a packed `source_jar`) so downstream `java_*` / `kt_*`
rules consume the outputs without any adapter, plus `ElideInfo` for
Elide-specific metadata propagation.

<a id="elide_java_binary"></a>

## elide_java_binary

<pre>
load("@rules_elide//elide/rules:java.bzl", "elide_java_binary")

elide_java_binary(<a href="#elide_java_binary-name">name</a>, <a href="#elide_java_binary-deps">deps</a>, <a href="#elide_java_binary-srcs">srcs</a>, <a href="#elide_java_binary-data">data</a>, <a href="#elide_java_binary-resources">resources</a>, <a href="#elide_java_binary-exported_compiler_plugins">exported_compiler_plugins</a>, <a href="#elide_java_binary-exports">exports</a>, <a href="#elide_java_binary-javac_opts">javac_opts</a>,
                  <a href="#elide_java_binary-jvm_flags">jvm_flags</a>, <a href="#elide_java_binary-main_class">main_class</a>, <a href="#elide_java_binary-neverlink">neverlink</a>, <a href="#elide_java_binary-plugins">plugins</a>, <a href="#elide_java_binary-resource_jars">resource_jars</a>, <a href="#elide_java_binary-runtime_deps">runtime_deps</a>)
</pre>



**ATTRIBUTES**


| Name  | Description | Type | Mandatory | Default |
| :------------- | :------------- | :------------- | :------------- | :------------- |
| <a id="elide_java_binary-name"></a>name |  A unique name for this target.   | <a href="https://bazel.build/concepts/labels#target-names">Name</a> | required |  |
| <a id="elide_java_binary-deps"></a>deps |  -   | <a href="https://bazel.build/concepts/labels">List of labels</a> | optional |  `[]`  |
| <a id="elide_java_binary-srcs"></a>srcs |  -   | <a href="https://bazel.build/concepts/labels">List of labels</a> | optional |  `[]`  |
| <a id="elide_java_binary-data"></a>data |  -   | <a href="https://bazel.build/concepts/labels">List of labels</a> | optional |  `[]`  |
| <a id="elide_java_binary-resources"></a>resources |  -   | <a href="https://bazel.build/concepts/labels">List of labels</a> | optional |  `[]`  |
| <a id="elide_java_binary-exported_compiler_plugins"></a>exported_compiler_plugins |  -   | <a href="https://bazel.build/concepts/labels">List of labels</a> | optional |  `[]`  |
| <a id="elide_java_binary-exports"></a>exports |  -   | <a href="https://bazel.build/concepts/labels">List of labels</a> | optional |  `[]`  |
| <a id="elide_java_binary-javac_opts"></a>javac_opts |  -   | List of strings | optional |  `[]`  |
| <a id="elide_java_binary-jvm_flags"></a>jvm_flags |  -   | List of strings | optional |  `[]`  |
| <a id="elide_java_binary-main_class"></a>main_class |  -   | String | required |  |
| <a id="elide_java_binary-neverlink"></a>neverlink |  -   | Boolean | optional |  `False`  |
| <a id="elide_java_binary-plugins"></a>plugins |  -   | <a href="https://bazel.build/concepts/labels">List of labels</a> | optional |  `[]`  |
| <a id="elide_java_binary-resource_jars"></a>resource_jars |  -   | <a href="https://bazel.build/concepts/labels">List of labels</a> | optional |  `[]`  |
| <a id="elide_java_binary-runtime_deps"></a>runtime_deps |  -   | <a href="https://bazel.build/concepts/labels">List of labels</a> | optional |  `[]`  |


<a id="elide_java_library"></a>

## elide_java_library

<pre>
load("@rules_elide//elide/rules:java.bzl", "elide_java_library")

elide_java_library(<a href="#elide_java_library-name">name</a>, <a href="#elide_java_library-deps">deps</a>, <a href="#elide_java_library-srcs">srcs</a>, <a href="#elide_java_library-data">data</a>, <a href="#elide_java_library-resources">resources</a>, <a href="#elide_java_library-exported_compiler_plugins">exported_compiler_plugins</a>, <a href="#elide_java_library-exports">exports</a>,
                   <a href="#elide_java_library-javac_opts">javac_opts</a>, <a href="#elide_java_library-neverlink">neverlink</a>, <a href="#elide_java_library-plugins">plugins</a>, <a href="#elide_java_library-resource_jars">resource_jars</a>, <a href="#elide_java_library-runtime_deps">runtime_deps</a>)
</pre>



**ATTRIBUTES**


| Name  | Description | Type | Mandatory | Default |
| :------------- | :------------- | :------------- | :------------- | :------------- |
| <a id="elide_java_library-name"></a>name |  A unique name for this target.   | <a href="https://bazel.build/concepts/labels#target-names">Name</a> | required |  |
| <a id="elide_java_library-deps"></a>deps |  -   | <a href="https://bazel.build/concepts/labels">List of labels</a> | optional |  `[]`  |
| <a id="elide_java_library-srcs"></a>srcs |  -   | <a href="https://bazel.build/concepts/labels">List of labels</a> | optional |  `[]`  |
| <a id="elide_java_library-data"></a>data |  -   | <a href="https://bazel.build/concepts/labels">List of labels</a> | optional |  `[]`  |
| <a id="elide_java_library-resources"></a>resources |  -   | <a href="https://bazel.build/concepts/labels">List of labels</a> | optional |  `[]`  |
| <a id="elide_java_library-exported_compiler_plugins"></a>exported_compiler_plugins |  -   | <a href="https://bazel.build/concepts/labels">List of labels</a> | optional |  `[]`  |
| <a id="elide_java_library-exports"></a>exports |  -   | <a href="https://bazel.build/concepts/labels">List of labels</a> | optional |  `[]`  |
| <a id="elide_java_library-javac_opts"></a>javac_opts |  -   | List of strings | optional |  `[]`  |
| <a id="elide_java_library-neverlink"></a>neverlink |  -   | Boolean | optional |  `False`  |
| <a id="elide_java_library-plugins"></a>plugins |  -   | <a href="https://bazel.build/concepts/labels">List of labels</a> | optional |  `[]`  |
| <a id="elide_java_library-resource_jars"></a>resource_jars |  -   | <a href="https://bazel.build/concepts/labels">List of labels</a> | optional |  `[]`  |
| <a id="elide_java_library-runtime_deps"></a>runtime_deps |  -   | <a href="https://bazel.build/concepts/labels">List of labels</a> | optional |  `[]`  |


<a id="elide_java_test"></a>

## elide_java_test

<pre>
load("@rules_elide//elide/rules:java.bzl", "elide_java_test")

elide_java_test(<a href="#elide_java_test-name">name</a>, <a href="#elide_java_test-deps">deps</a>, <a href="#elide_java_test-srcs">srcs</a>, <a href="#elide_java_test-data">data</a>, <a href="#elide_java_test-resources">resources</a>, <a href="#elide_java_test-exported_compiler_plugins">exported_compiler_plugins</a>, <a href="#elide_java_test-exports">exports</a>, <a href="#elide_java_test-javac_opts">javac_opts</a>,
                <a href="#elide_java_test-jvm_flags">jvm_flags</a>, <a href="#elide_java_test-neverlink">neverlink</a>, <a href="#elide_java_test-plugins">plugins</a>, <a href="#elide_java_test-resource_jars">resource_jars</a>, <a href="#elide_java_test-runtime_deps">runtime_deps</a>, <a href="#elide_java_test-test_class">test_class</a>)
</pre>



**ATTRIBUTES**


| Name  | Description | Type | Mandatory | Default |
| :------------- | :------------- | :------------- | :------------- | :------------- |
| <a id="elide_java_test-name"></a>name |  A unique name for this target.   | <a href="https://bazel.build/concepts/labels#target-names">Name</a> | required |  |
| <a id="elide_java_test-deps"></a>deps |  -   | <a href="https://bazel.build/concepts/labels">List of labels</a> | optional |  `[]`  |
| <a id="elide_java_test-srcs"></a>srcs |  -   | <a href="https://bazel.build/concepts/labels">List of labels</a> | optional |  `[]`  |
| <a id="elide_java_test-data"></a>data |  -   | <a href="https://bazel.build/concepts/labels">List of labels</a> | optional |  `[]`  |
| <a id="elide_java_test-resources"></a>resources |  -   | <a href="https://bazel.build/concepts/labels">List of labels</a> | optional |  `[]`  |
| <a id="elide_java_test-exported_compiler_plugins"></a>exported_compiler_plugins |  -   | <a href="https://bazel.build/concepts/labels">List of labels</a> | optional |  `[]`  |
| <a id="elide_java_test-exports"></a>exports |  -   | <a href="https://bazel.build/concepts/labels">List of labels</a> | optional |  `[]`  |
| <a id="elide_java_test-javac_opts"></a>javac_opts |  -   | List of strings | optional |  `[]`  |
| <a id="elide_java_test-jvm_flags"></a>jvm_flags |  -   | List of strings | optional |  `[]`  |
| <a id="elide_java_test-neverlink"></a>neverlink |  -   | Boolean | optional |  `False`  |
| <a id="elide_java_test-plugins"></a>plugins |  -   | <a href="https://bazel.build/concepts/labels">List of labels</a> | optional |  `[]`  |
| <a id="elide_java_test-resource_jars"></a>resource_jars |  -   | <a href="https://bazel.build/concepts/labels">List of labels</a> | optional |  `[]`  |
| <a id="elide_java_test-runtime_deps"></a>runtime_deps |  -   | <a href="https://bazel.build/concepts/labels">List of labels</a> | optional |  `[]`  |
| <a id="elide_java_test-test_class"></a>test_class |  Single JUnit Platform test class to select. Empty -> --scan-classpath.   | String | optional |  `""`  |
