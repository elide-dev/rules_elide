<!-- Generated with Stardoc: http://skydoc.bazel.build -->

Bzlmod module extension wiring the elide toolchain into a consumer build.

<a id="elide"></a>

## elide

<pre>
elide = use_extension("@rules_elide//elide:extensions.bzl", "elide")
elide.install(<a href="#elide.install-channel">channel</a>, <a href="#elide.install-repo_prefix">repo_prefix</a>, <a href="#elide.install-url_template">url_template</a>, <a href="#elide.install-version">version</a>)
</pre>


**TAG CLASSES**

<a id="elide.install"></a>

### install

**Attributes**

| Name  | Description | Type | Mandatory | Default |
| :------------- | :------------- | :------------- | :------------- | :------------- |
| <a id="elide.install-channel"></a>channel |  Release channel: nightly, preview, or release.   | String | optional |  `"nightly"`  |
| <a id="elide.install-repo_prefix"></a>repo_prefix |  Prefix used to name per-platform download repos.   | String | optional |  `"elide"`  |
| <a id="elide.install-url_template"></a>url_template |  Override release URL template. Tokens: {channel}, {version}, {os}, {cpu}, {ext}.   | String | optional |  `""`  |
| <a id="elide.install-version"></a>version |  Elide release version (e.g. `latest` or a concrete tag).   | String | required |  |
