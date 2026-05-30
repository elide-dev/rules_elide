<!-- Generated with Stardoc: http://skydoc.bazel.build -->

Native image rule for rules_elide.

`elide_native_image` compiles JVM bytecode (provided via JavaInfo deps) into
a standalone native executable using the Elide CLI's native-image pipeline.

<a id="elide_native_image"></a>

## elide_native_image

<pre>
load("@rules_elide//elide/rules:native_image.bzl", "elide_native_image")

elide_native_image(<a href="#elide_native_image-name">name</a>, <a href="#elide_native_image-deps">deps</a>, <a href="#elide_native_image-main_class">main_class</a>, <a href="#elide_native_image-native_image_opts">native_image_opts</a>)
</pre>



**ATTRIBUTES**


| Name  | Description | Type | Mandatory | Default |
| :------------- | :------------- | :------------- | :------------- | :------------- |
| <a id="elide_native_image-name"></a>name |  A unique name for this target.   | <a href="https://bazel.build/concepts/labels#target-names">Name</a> | required |  |
| <a id="elide_native_image-deps"></a>deps |  JVM dependencies whose runtime classpath enters the native image.   | <a href="https://bazel.build/concepts/labels">List of labels</a> | optional |  `[]`  |
| <a id="elide_native_image-main_class"></a>main_class |  Fully qualified main class.   | String | required |  |
| <a id="elide_native_image-native_image_opts"></a>native_image_opts |  Extra flags appended to the elide native-image invocation.   | List of strings | optional |  `[]`  |
