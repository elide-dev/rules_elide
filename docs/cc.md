<!-- Generated with Stardoc: http://skydoc.bazel.build -->

Hermetic C executables built with the LLVM toolchain bundled in Elide.

<a id="elide_cc_binary"></a>

## elide_cc_binary

<pre>
load("@rules_elide//elide/rules:cc.bzl", "elide_cc_binary")

elide_cc_binary(<a href="#elide_cc_binary-name">name</a>, <a href="#elide_cc_binary-srcs">srcs</a>, <a href="#elide_cc_binary-data">data</a>, <a href="#elide_cc_binary-hdrs">hdrs</a>, <a href="#elide_cc_binary-copts">copts</a>, <a href="#elide_cc_binary-defines">defines</a>, <a href="#elide_cc_binary-linkopts">linkopts</a>)
</pre>

Compiles and links a C executable with Elide's bundled LLVM toolchain.

Each `.c` source is compiled in its own action, then linked with lld against the
distribution's glibc sysroot, compiler-rt, and libunwind. Actions use only the
toolchain's declared `cc_tool_files`, run with an empty environment, and never
consult a host compiler, headers, or libraries. Output targets the toolchain's
own Linux platform; cross-compilation and C++ are not supported.

`elide cc` itself is not used: in Elide 1.6.3 it only compiles a single
freestanding source without system headers or linking.

**ATTRIBUTES**


| Name  | Description | Type | Mandatory | Default |
| :------------- | :------------- | :------------- | :------------- | :------------- |
| <a id="elide_cc_binary-name"></a>name |  A unique name for this target.   | <a href="https://bazel.build/concepts/labels#target-names">Name</a> | required |  |
| <a id="elide_cc_binary-srcs"></a>srcs |  C sources and private headers.   | <a href="https://bazel.build/concepts/labels">List of labels</a> | required |  |
| <a id="elide_cc_binary-data"></a>data |  Runtime data files.   | <a href="https://bazel.build/concepts/labels">List of labels</a> | optional |  `[]`  |
| <a id="elide_cc_binary-hdrs"></a>hdrs |  Headers included by srcs. Include them by workspace-relative path.   | <a href="https://bazel.build/concepts/labels">List of labels</a> | optional |  `[]`  |
| <a id="elide_cc_binary-copts"></a>copts |  Additional compiler options, e.g. `-O2` or `-Wall`.   | List of strings | optional |  `[]`  |
| <a id="elide_cc_binary-defines"></a>defines |  Preprocessor definitions, NAME or NAME=VALUE.   | List of strings | optional |  `[]`  |
| <a id="elide_cc_binary-linkopts"></a>linkopts |  Additional linker driver options, e.g. `-lm`.   | List of strings | optional |  `[]`  |
