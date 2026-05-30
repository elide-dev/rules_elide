<!-- Generated with Stardoc: http://skydoc.bazel.build -->

Public providers for rules_elide.

<a id="ElideInfo"></a>

## ElideInfo

<pre>
load("@rules_elide//elide:providers.bzl", "ElideInfo")

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
load("@rules_elide//elide:providers.bzl", "ElideToolchainInfo")

ElideToolchainInfo(<a href="#ElideToolchainInfo-binary">binary</a>, <a href="#ElideToolchainInfo-tool_files">tool_files</a>, <a href="#ElideToolchainInfo-version">version</a>)
</pre>

Resolved Elide toolchain information.

**FIELDS**

| Name  | Description |
| :------------- | :------------- |
| <a id="ElideToolchainInfo-binary"></a>binary |  File. The elide binary executable.    |
| <a id="ElideToolchainInfo-tool_files"></a>tool_files |  depset[File]. All runfiles required to invoke elide.    |
| <a id="ElideToolchainInfo-version"></a>version |  string. Semantic version of the elide binary.    |
