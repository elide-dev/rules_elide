<!-- Generated with Stardoc: http://skydoc.bazel.build -->

Explicit KAPT and KSP2 source-generation actions (Elide 1.6.2+).

<a id="elide_kapt"></a>

## elide_kapt

<pre>
load("@rules_elide//elide/rules:processing.bzl", "elide_kapt")

elide_kapt(<a href="#elide_kapt-name">name</a>, <a href="#elide_kapt-deps">deps</a>, <a href="#elide_kapt-srcs">srcs</a>, <a href="#elide_kapt-data">data</a>, <a href="#elide_kapt-kotlinc_opts">kotlinc_opts</a>, <a href="#elide_kapt-processor_deps">processor_deps</a>, <a href="#elide_kapt-processor_jars">processor_jars</a>, <a href="#elide_kapt-processor_options">processor_options</a>,
           <a href="#elide_kapt-processors">processors</a>)
</pre>



**ATTRIBUTES**


| Name  | Description | Type | Mandatory | Default |
| :------------- | :------------- | :------------- | :------------- | :------------- |
| <a id="elide_kapt-name"></a>name |  A unique name for this target.   | <a href="https://bazel.build/concepts/labels#target-names">Name</a> | required |  |
| <a id="elide_kapt-deps"></a>deps |  Source compile classpath.   | <a href="https://bazel.build/concepts/labels">List of labels</a> | optional |  `[]`  |
| <a id="elide_kapt-srcs"></a>srcs |  -   | <a href="https://bazel.build/concepts/labels">List of labels</a> | required |  |
| <a id="elide_kapt-data"></a>data |  Additional files read by processors.   | <a href="https://bazel.build/concepts/labels">List of labels</a> | optional |  `[]`  |
| <a id="elide_kapt-kotlinc_opts"></a>kotlinc_opts |  -   | List of strings | optional |  `[]`  |
| <a id="elide_kapt-processor_deps"></a>processor_deps |  Processor runtime dependencies.   | <a href="https://bazel.build/concepts/labels">List of labels</a> | optional |  `[]`  |
| <a id="elide_kapt-processor_jars"></a>processor_jars |  Additional processor jars.   | <a href="https://bazel.build/concepts/labels">List of labels</a> | optional |  `[]`  |
| <a id="elide_kapt-processor_options"></a>processor_options |  Processor options passed as key=value.   | <a href="https://bazel.build/rules/lib/core/dict">Dictionary: String -> String</a> | optional |  `{}`  |
| <a id="elide_kapt-processors"></a>processors |  KAPT processor class names; empty means service discovery.   | List of strings | optional |  `[]`  |


<a id="elide_ksp"></a>

## elide_ksp

<pre>
load("@rules_elide//elide/rules:processing.bzl", "elide_ksp")

elide_ksp(<a href="#elide_ksp-name">name</a>, <a href="#elide_ksp-deps">deps</a>, <a href="#elide_ksp-srcs">srcs</a>, <a href="#elide_ksp-data">data</a>, <a href="#elide_ksp-kotlinc_opts">kotlinc_opts</a>, <a href="#elide_ksp-processor_deps">processor_deps</a>, <a href="#elide_ksp-processor_jars">processor_jars</a>, <a href="#elide_ksp-processor_options">processor_options</a>,
          <a href="#elide_ksp-processors">processors</a>)
</pre>



**ATTRIBUTES**


| Name  | Description | Type | Mandatory | Default |
| :------------- | :------------- | :------------- | :------------- | :------------- |
| <a id="elide_ksp-name"></a>name |  A unique name for this target.   | <a href="https://bazel.build/concepts/labels#target-names">Name</a> | required |  |
| <a id="elide_ksp-deps"></a>deps |  Source compile classpath.   | <a href="https://bazel.build/concepts/labels">List of labels</a> | optional |  `[]`  |
| <a id="elide_ksp-srcs"></a>srcs |  -   | <a href="https://bazel.build/concepts/labels">List of labels</a> | required |  |
| <a id="elide_ksp-data"></a>data |  Additional files read by processors.   | <a href="https://bazel.build/concepts/labels">List of labels</a> | optional |  `[]`  |
| <a id="elide_ksp-kotlinc_opts"></a>kotlinc_opts |  -   | List of strings | optional |  `[]`  |
| <a id="elide_ksp-processor_deps"></a>processor_deps |  Processor runtime dependencies.   | <a href="https://bazel.build/concepts/labels">List of labels</a> | optional |  `[]`  |
| <a id="elide_ksp-processor_jars"></a>processor_jars |  Additional processor jars.   | <a href="https://bazel.build/concepts/labels">List of labels</a> | optional |  `[]`  |
| <a id="elide_ksp-processor_options"></a>processor_options |  Processor options passed as key=value.   | <a href="https://bazel.build/rules/lib/core/dict">Dictionary: String -> String</a> | optional |  `{}`  |
| <a id="elide_ksp-processors"></a>processors |  KAPT processor class names; empty means service discovery.   | List of strings | optional |  `[]`  |
