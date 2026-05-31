<!-- Generated with Stardoc: http://skydoc.bazel.build -->

Source-code formatter rule for rules_elide.

`elide_format` is a runnable target (`bazel run`) that formats its `srcs`
in place via the embedded Elide formatters:

  - `.java` sources -> `elide javaformat` (google-java-format)
  - `.kt` / `.kts` sources -> `elide ktfmt`

A target may not mix languages; split into two `elide_format` targets if
the source set spans both.

<a id="elide_format"></a>

## elide_format

<pre>
load("@rules_elide//elide/rules:format.bzl", "elide_format")

elide_format(<a href="#elide_format-name">name</a>, <a href="#elide_format-srcs">srcs</a>)
</pre>



**ATTRIBUTES**


| Name  | Description | Type | Mandatory | Default |
| :------------- | :------------- | :------------- | :------------- | :------------- |
| <a id="elide_format-name"></a>name |  A unique name for this target.   | <a href="https://bazel.build/concepts/labels#target-names">Name</a> | required |  |
| <a id="elide_format-srcs"></a>srcs |  Source files to format. All must be .java or all .kt/.kts.   | <a href="https://bazel.build/concepts/labels">List of labels</a> | required |  |
