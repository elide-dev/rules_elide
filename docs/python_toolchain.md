<!-- Generated with Stardoc: http://skydoc.bazel.build -->

Opt-in rules_python runtime backed by an Elide Python overlay.

<a id="register_elide_python_toolchain"></a>

## register_elide_python_toolchain

<pre>
load("@rules_elide//elide/python:toolchain.bzl", "register_elide_python_toolchain")

register_elide_python_toolchain(<a href="#register_elide_python_toolchain-name">name</a>, <a href="#register_elide_python_toolchain-elide">elide</a>, <a href="#register_elide_python_toolchain-runtime_files">runtime_files</a>, <a href="#register_elide_python_toolchain-target_compatible_with">target_compatible_with</a>, <a href="#register_elide_python_toolchain-visibility">visibility</a>)
</pre>

Declare an Elide Python runtime; register its name from MODULE.bazel.

**PARAMETERS**


| Name  | Description | Default Value |
| :------------- | :------------- | :------------- |
| <a id="register_elide_python_toolchain-name"></a>name |  Toolchain target name to register with register_toolchains.   |  none |
| <a id="register_elide_python_toolchain-elide"></a>elide |  Matching distribution's bin/elide label (target platform).   |  none |
| <a id="register_elide_python_toolchain-runtime_files"></a>runtime_files |  Same distribution's elide_python_files label, with overlay installed.   |  none |
| <a id="register_elide_python_toolchain-target_compatible_with"></a>target_compatible_with |  OS and CPU constraints matching that distribution.   |  none |
| <a id="register_elide_python_toolchain-visibility"></a>visibility |  Visibility of generated targets.   |  `None` |
