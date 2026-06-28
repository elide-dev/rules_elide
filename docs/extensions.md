<!-- Generated with Stardoc: http://skydoc.bazel.build -->

Bzlmod module extension wiring the elide toolchain into a consumer build.

<a id="elide"></a>

## elide

<pre>
elide = use_extension("@rules_elide//elide:extensions.bzl", "elide")
elide.install(<a href="#elide.install-channel">channel</a>, <a href="#elide.install-repo_prefix">repo_prefix</a>, <a href="#elide.install-url_template">url_template</a>, <a href="#elide.install-version">version</a>)
elide.use(<a href="#elide.use-channel">channel</a>, <a href="#elide.use-integrity">integrity</a>, <a href="#elide.use-local_path">local_path</a>, <a href="#elide.use-repo_prefix">repo_prefix</a>, <a href="#elide.use-url_template">url_template</a>, <a href="#elide.use-version">version</a>)
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
| <a id="elide.install-version"></a>version |  Elide release version tag, e.g. `1.2.0+20260602`. Must match an entry in elide/private/versions.bzl. Defaults to the most-recently verified release.   | String | optional |  `"1.3.6+20260628"`  |

<a id="elide.use"></a>

### use

**Attributes**

| Name  | Description | Type | Mandatory | Default |
| :------------- | :------------- | :------------- | :------------- | :------------- |
| <a id="elide.use-channel"></a>channel |  Release channel token for `url_template`. Default nightly.   | String | optional |  `"nightly"`  |
| <a id="elide.use-integrity"></a>integrity |  Per-platform SRI for a BYO release: keys `<os>_<cpu>` (e.g. `linux_amd64`) -> `sha256-<base64>`. Required together with `url_template`; ignored when `local_path` is set. Only the platforms listed here get a toolchain.   | <a href="https://bazel.build/rules/lib/core/dict">Dictionary: String -> String</a> | optional |  `{}`  |
| <a id="elide.use-local_path"></a>local_path |  Absolute path to an already-extracted Elide distribution (contains bin/elide, lib/, ...). When set, the host-platform toolchain uses it directly with no download (build becomes non-reproducible); takes precedence over url_template/integrity.   | String | optional |  `""`  |
| <a id="elide.use-repo_prefix"></a>repo_prefix |  Prefix used to name per-platform toolchain repos.   | String | optional |  `"elide"`  |
| <a id="elide.use-url_template"></a>url_template |  URL template for a BYO release. Tokens: {channel}, {version}, {os}, {cpu}, {ext}. May be a file:// URL.   | String | optional |  `""`  |
| <a id="elide.use-version"></a>version |  Version tag for the BYO release; used in URLs and as the toolchain version label. Need not appear in versions.bzl.   | String | optional |  `""`  |
