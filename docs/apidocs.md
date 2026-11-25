<!-- Generated with Stardoc: http://skydoc.bazel.build -->

API reference sites from `JavaInfo` targets, rendered by a custom doclet.

`elide_apidocs` runs javadoc once over the source jars of `deps` with a custom doclet,
[elide-dev/doclet](https://github.com/elide-dev/doclet) by default. The doclet renders through
a JavaScript runtime; the rule supplies the Elide binary from the registered Elide toolchain, so
neither Node nor Bun has to be installed.

<a id="elide_apidocs"></a>

## elide_apidocs

<pre>
load("@rules_elide//elide/rules:apidocs.bzl", "elide_apidocs")

elide_apidocs(<a href="#elide_apidocs-name">name</a>, <a href="#elide_apidocs-deps">deps</a>, <a href="#elide_apidocs-data">data</a>, <a href="#elide_apidocs-doclet">doclet</a>, <a href="#elide_apidocs-doclet_class">doclet_class</a>, <a href="#elide_apidocs-exclude_packages">exclude_packages</a>, <a href="#elide_apidocs-generated_sources">generated_sources</a>,
              <a href="#elide_apidocs-java_runtime">java_runtime</a>, <a href="#elide_apidocs-javadoc_opts">javadoc_opts</a>, <a href="#elide_apidocs-jvm_flags">jvm_flags</a>, <a href="#elide_apidocs-links">links</a>, <a href="#elide_apidocs-module_name">module_name</a>, <a href="#elide_apidocs-offline_links">offline_links</a>, <a href="#elide_apidocs-packages">packages</a>,
              <a href="#elide_apidocs-problems">problems</a>, <a href="#elide_apidocs-source_ref">source_ref</a>, <a href="#elide_apidocs-theme">theme</a>, <a href="#elide_apidocs-title">title</a>, <a href="#elide_apidocs-version">version</a>)
</pre>

Generates an API reference site with a custom doclet.

Javadoc runs once, in unnamed-module `-sourcepath` mode, over the unpacked source jars of
`deps` (module descriptors are dropped), the way `mx javadoc --unified` documents several
projects as one reference. The compile classpath is the transitive compile classpath of `deps`,
so public API that refers to annotation-processor-generated classes resolves.

javadoc comes from `java_runtime`: by default the execution-platform runtime that
`--tool_java_runtime_version` selects. elide-dev/doclet needs JDK 25. Documenting GraalVM
sources needs a JDK without GraalVM modules, such as LabsJDK: a GraalVM JDK already contains
`org.graalvm.*`, and javadoc fails with "package exists in another module".

The doclet renders through the Elide binary of the registered Elide toolchain, passed as the
`APIDOCS_JS_RUNTIME` environment variable. Outputs are the site directory (`<name>_site`,
output group `apidocs_site`) and a reproducible `<name>.tar.gz` (output group
`apidocs_archive`).

```starlark
elide_apidocs(
    name = "api_reference",
    deps = [":api"],
    doclet = "@elide_doclet//:doclet",
    packages = ["com.example.api"],
    title = "Example API",
    version = "1.0.0",
)
```

**ATTRIBUTES**


| Name  | Description | Type | Mandatory | Default |
| :------------- | :------------- | :------------- | :------------- | :------------- |
| <a id="elide_apidocs-name"></a>name |  A unique name for this target.   | <a href="https://bazel.build/concepts/labels#target-names">Name</a> | required |  |
| <a id="elide_apidocs-deps"></a>deps |  Targets to document. Their source jars are the sources, and their transitive compile jars the classpath.   | <a href="https://bazel.build/concepts/labels">List of labels</a> | required |  |
| <a id="elide_apidocs-data"></a>data |  Files that `javadoc_opts` refer to with `$(location)`.   | <a href="https://bazel.build/concepts/labels">List of labels</a> | optional |  `[]`  |
| <a id="elide_apidocs-doclet"></a>doclet |  The doclet: a jar, or a target providing `JavaInfo` (its runtime classpath becomes `-docletpath`). elide-dev/doclet has no release yet; build it from a pinned commit (see docs/api_reference.md).   | <a href="https://bazel.build/concepts/labels">Label</a> | required |  |
| <a id="elide_apidocs-doclet_class"></a>doclet_class |  The doclet's class.   | String | optional |  `"dev.elide.doclet.ElideDoclet"`  |
| <a id="elide_apidocs-exclude_packages"></a>exclude_packages |  Packages left out, with their subpackages (`-exclude`).   | List of strings | optional |  `[]`  |
| <a id="elide_apidocs-generated_sources"></a>generated_sources |  Also document the annotation-processor source jars of `deps`, as `mx javadoc` does. When false, generated classes are still on the classpath.   | Boolean | optional |  `True`  |
| <a id="elide_apidocs-java_runtime"></a>java_runtime |  The JDK that runs javadoc. The default follows `--tool_java_runtime_version`.   | <a href="https://bazel.build/concepts/labels">Label</a> | optional |  `"@bazel_tools//tools/jdk:current_java_runtime"`  |
| <a id="elide_apidocs-javadoc_opts"></a>javadoc_opts |  Additional javadoc and doclet options, after the generated ones. `$(location)` expands labels in `data`.   | List of strings | optional |  `[]`  |
| <a id="elide_apidocs-jvm_flags"></a>jvm_flags |  JVM flags for the javadoc process, such as `-Xmx4g`.   | List of strings | optional |  `[]`  |
| <a id="elide_apidocs-links"></a>links |  Javadoc sites to link to (`-link`). javadoc downloads each `element-list`, which needs network access in the action; prefer `offline_links`.   | List of strings | optional |  `[]`  |
| <a id="elide_apidocs-module_name"></a>module_name |  Library name in `api.json` (`--module-name`); defaults to `title`.   | String | optional |  `""`  |
| <a id="elide_apidocs-offline_links"></a>offline_links |  Javadoc sites to link to without network access (`-linkoffline`): site URL to a label of its `element-list` file, or of a directory holding it.   | Dictionary: String -> Label | optional |  `{}`  |
| <a id="elide_apidocs-packages"></a>packages |  Packages to document, with their subpackages (`-subpackages`). Empty documents every package in the source jars.   | List of strings | optional |  `[]`  |
| <a id="elide_apidocs-problems"></a>problems |  How the doclet reports comments it cannot represent (`--problems`), such as `warning` or `error,inheritdoc=warning`. The doclet's default is `error`.   | String | optional |  `""`  |
| <a id="elide_apidocs-source_ref"></a>source_ref |  Revision for source links (`--source-ref`).   | String | optional |  `""`  |
| <a id="elide_apidocs-theme"></a>theme |  Renderer theme JSON (`--theme`).   | <a href="https://bazel.build/concepts/labels">Label</a> | optional |  `None`  |
| <a id="elide_apidocs-title"></a>title |  Reference title (`-doctitle` and `-windowtitle`).   | String | optional |  `""`  |
| <a id="elide_apidocs-version"></a>version |  Library version in `api.json` (`--module-version`).   | String | optional |  `""`  |
