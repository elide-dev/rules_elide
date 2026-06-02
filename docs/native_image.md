<!-- Generated with Stardoc: http://skydoc.bazel.build -->

Native image rule for rules_elide.

`elide_native_image` runs `elide native-image` to compile JVM bytecode
(provided via JavaInfo deps) into a standalone native executable.

<a id="elide_native_image"></a>

## elide_native_image

<pre>
load("@rules_elide//elide/rules:native_image.bzl", "elide_native_image")

elide_native_image(<a href="#elide_native_image-name">name</a>, <a href="#elide_native_image-deps">deps</a>, <a href="#elide_native_image-main_class">main_class</a>, <a href="#elide_native_image-native_image_opts">native_image_opts</a>, <a href="#elide_native_image-strip_uuid">strip_uuid</a>)
</pre>



**ATTRIBUTES**


| Name  | Description | Type | Mandatory | Default |
| :------------- | :------------- | :------------- | :------------- | :------------- |
| <a id="elide_native_image-name"></a>name |  A unique name for this target.   | <a href="https://bazel.build/concepts/labels#target-names">Name</a> | required |  |
| <a id="elide_native_image-deps"></a>deps |  JVM dependencies whose runtime classpath enters the native image.   | <a href="https://bazel.build/concepts/labels">List of labels</a> | optional |  `[]`  |
| <a id="elide_native_image-main_class"></a>main_class |  Fully qualified main class.   | String | required |  |
| <a id="elide_native_image-native_image_opts"></a>native_image_opts |  Extra flags appended to the native-image invocation.   | List of strings | optional |  `[]`  |
| <a id="elide_native_image-strip_uuid"></a>strip_uuid |  Strip the Mach-O LC_UUID from the output binary (macOS only). GraalVM generates a random UUID per build; stripping it makes the binary byte-identical across clean builds. Disables UUID-based dSYM lookup.   | Boolean | optional |  `False`  |
