<!-- Generated with Stardoc: http://skydoc.bazel.build -->

Documentation, archives, bytecode reports, and C binding generation with Elide.

<a id="elide_jar"></a>

## elide_jar

<pre>
load("@rules_elide//elide/rules:jvm_tools.bzl", "elide_jar")

elide_jar(<a href="#elide_jar-name">name</a>, <a href="#elide_jar-srcs">srcs</a>, <a href="#elide_jar-main_class">main_class</a>, <a href="#elide_jar-manifest">manifest</a>, <a href="#elide_jar-strip_prefix">strip_prefix</a>)
</pre>



**ATTRIBUTES**


| Name  | Description | Type | Mandatory | Default |
| :------------- | :------------- | :------------- | :------------- | :------------- |
| <a id="elide_jar-name"></a>name |  A unique name for this target.   | <a href="https://bazel.build/concepts/labels#target-names">Name</a> | required |  |
| <a id="elide_jar-srcs"></a>srcs |  Files or directory artifacts to archive; input jars are stored, not merged.   | <a href="https://bazel.build/concepts/labels">List of labels</a> | required |  |
| <a id="elide_jar-main_class"></a>main_class |  -   | String | optional |  `""`  |
| <a id="elide_jar-manifest"></a>manifest |  -   | <a href="https://bazel.build/concepts/labels">Label</a> | optional |  `None`  |
| <a id="elide_jar-strip_prefix"></a>strip_prefix |  Prefix removed from workspace-relative file paths. Directory contents are stored at the archive root.   | String | optional |  `""`  |


<a id="elide_javadoc"></a>

## elide_javadoc

<pre>
load("@rules_elide//elide/rules:jvm_tools.bzl", "elide_javadoc")

elide_javadoc(<a href="#elide_javadoc-name">name</a>, <a href="#elide_javadoc-deps">deps</a>, <a href="#elide_javadoc-srcs">srcs</a>, <a href="#elide_javadoc-data">data</a>, <a href="#elide_javadoc-doclet">doclet</a>, <a href="#elide_javadoc-doclet_deps">doclet_deps</a>, <a href="#elide_javadoc-jar">jar</a>, <a href="#elide_javadoc-opts">opts</a>, <a href="#elide_javadoc-theme">theme</a>)
</pre>



**ATTRIBUTES**


| Name  | Description | Type | Mandatory | Default |
| :------------- | :------------- | :------------- | :------------- | :------------- |
| <a id="elide_javadoc-name"></a>name |  A unique name for this target.   | <a href="https://bazel.build/concepts/labels#target-names">Name</a> | required |  |
| <a id="elide_javadoc-deps"></a>deps |  Compile classpath for documented sources.   | <a href="https://bazel.build/concepts/labels">List of labels</a> | optional |  `[]`  |
| <a id="elide_javadoc-srcs"></a>srcs |  Java source files to document.   | <a href="https://bazel.build/concepts/labels">List of labels</a> | required |  |
| <a id="elide_javadoc-data"></a>data |  Declared doclet resources and offline link metadata.   | <a href="https://bazel.build/concepts/labels">List of labels</a> | optional |  `[]`  |
| <a id="elide_javadoc-doclet"></a>doclet |  Optional custom doclet class.   | String | optional |  `""`  |
| <a id="elide_javadoc-doclet_deps"></a>doclet_deps |  Custom doclet runtime dependencies.   | <a href="https://bazel.build/concepts/labels">List of labels</a> | optional |  `[]`  |
| <a id="elide_javadoc-jar"></a>jar |  Also produce a reproducible -javadoc.jar.   | Boolean | optional |  `True`  |
| <a id="elide_javadoc-opts"></a>opts |  Additional javadoc options; declare referenced files in data.   | List of strings | optional |  `[]`  |
| <a id="elide_javadoc-theme"></a>theme |  -   | String | optional |  `"default"`  |


<a id="elide_javap"></a>

## elide_javap

<pre>
load("@rules_elide//elide/rules:jvm_tools.bzl", "elide_javap")

elide_javap(<a href="#elide_javap-name">name</a>, <a href="#elide_javap-deps">deps</a>, <a href="#elide_javap-srcs">srcs</a>, <a href="#elide_javap-data">data</a>, <a href="#elide_javap-classes">classes</a>, <a href="#elide_javap-opts">opts</a>)
</pre>



**ATTRIBUTES**


| Name  | Description | Type | Mandatory | Default |
| :------------- | :------------- | :------------- | :------------- | :------------- |
| <a id="elide_javap-name"></a>name |  A unique name for this target.   | <a href="https://bazel.build/concepts/labels#target-names">Name</a> | required |  |
| <a id="elide_javap-deps"></a>deps |  Runtime classpath used to resolve classes.   | <a href="https://bazel.build/concepts/labels">List of labels</a> | optional |  `[]`  |
| <a id="elide_javap-srcs"></a>srcs |  Jars or class files to analyze with jdeps.   | <a href="https://bazel.build/concepts/labels">List of labels</a> | optional |  `[]`  |
| <a id="elide_javap-data"></a>data |  -   | <a href="https://bazel.build/concepts/labels">List of labels</a> | optional |  `[]`  |
| <a id="elide_javap-classes"></a>classes |  Fully qualified classes to inspect with javap.   | List of strings | optional |  `[]`  |
| <a id="elide_javap-opts"></a>opts |  -   | List of strings | optional |  `[]`  |


<a id="elide_jdeps"></a>

## elide_jdeps

<pre>
load("@rules_elide//elide/rules:jvm_tools.bzl", "elide_jdeps")

elide_jdeps(<a href="#elide_jdeps-name">name</a>, <a href="#elide_jdeps-deps">deps</a>, <a href="#elide_jdeps-srcs">srcs</a>, <a href="#elide_jdeps-data">data</a>, <a href="#elide_jdeps-classes">classes</a>, <a href="#elide_jdeps-opts">opts</a>)
</pre>



**ATTRIBUTES**


| Name  | Description | Type | Mandatory | Default |
| :------------- | :------------- | :------------- | :------------- | :------------- |
| <a id="elide_jdeps-name"></a>name |  A unique name for this target.   | <a href="https://bazel.build/concepts/labels#target-names">Name</a> | required |  |
| <a id="elide_jdeps-deps"></a>deps |  Runtime classpath used to resolve classes.   | <a href="https://bazel.build/concepts/labels">List of labels</a> | optional |  `[]`  |
| <a id="elide_jdeps-srcs"></a>srcs |  Jars or class files to analyze with jdeps.   | <a href="https://bazel.build/concepts/labels">List of labels</a> | optional |  `[]`  |
| <a id="elide_jdeps-data"></a>data |  -   | <a href="https://bazel.build/concepts/labels">List of labels</a> | optional |  `[]`  |
| <a id="elide_jdeps-classes"></a>classes |  Fully qualified classes to inspect with javap.   | List of strings | optional |  `[]`  |
| <a id="elide_jdeps-opts"></a>opts |  -   | List of strings | optional |  `[]`  |


<a id="elide_jextract"></a>

## elide_jextract

<pre>
load("@rules_elide//elide/rules:jvm_tools.bzl", "elide_jextract")

elide_jextract(<a href="#elide_jextract-name">name</a>, <a href="#elide_jextract-srcs">srcs</a>, <a href="#elide_jextract-data">data</a>, <a href="#elide_jextract-hdrs">hdrs</a>, <a href="#elide_jextract-defines">defines</a>, <a href="#elide_jextract-header_class">header_class</a>, <a href="#elide_jextract-includes">includes</a>, <a href="#elide_jextract-opts">opts</a>, <a href="#elide_jextract-package">package</a>)
</pre>



**ATTRIBUTES**


| Name  | Description | Type | Mandatory | Default |
| :------------- | :------------- | :------------- | :------------- | :------------- |
| <a id="elide_jextract-name"></a>name |  A unique name for this target.   | <a href="https://bazel.build/concepts/labels#target-names">Name</a> | required |  |
| <a id="elide_jextract-srcs"></a>srcs |  Entry-point C headers.   | <a href="https://bazel.build/concepts/labels">List of labels</a> | required |  |
| <a id="elide_jextract-data"></a>data |  -   | <a href="https://bazel.build/concepts/labels">List of labels</a> | optional |  `[]`  |
| <a id="elide_jextract-hdrs"></a>hdrs |  Transitive included headers; their directories are added to the include path.   | <a href="https://bazel.build/concepts/labels">List of labels</a> | optional |  `[]`  |
| <a id="elide_jextract-defines"></a>defines |  Preprocessor definitions, NAME or NAME=VALUE.   | List of strings | optional |  `[]`  |
| <a id="elide_jextract-header_class"></a>header_class |  Generated header class name.   | String | optional |  `""`  |
| <a id="elide_jextract-includes"></a>includes |  Additional execroot-relative include directories; declare all files in hdrs/data.   | List of strings | optional |  `[]`  |
| <a id="elide_jextract-opts"></a>opts |  Additional jextract options, such as symbol filters and library names.   | List of strings | optional |  `[]`  |
| <a id="elide_jextract-package"></a>package |  Generated Java package.   | String | optional |  `""`  |
