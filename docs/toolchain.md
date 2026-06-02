<!-- Generated with Stardoc: http://skydoc.bazel.build -->

The elide_toolchain rule wraps a concrete elide binary as a Bazel toolchain.

<a id="elide_toolchain"></a>

## elide_toolchain

<pre>
load("@rules_elide//elide:toolchain.bzl", "elide_toolchain")

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
