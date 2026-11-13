# Sample use cases

These examples point to checked-in workspaces with pinned dependencies. Run the
commands from the repository root; each subshell selects the correct workspace.
The verification runner checks artifacts in addition to building targets.

## Publish Java API documentation and inspect a library

The [JVM sample BUILD](../e2e/integration/BUILD.bazel) documents `sample.Hello`,
packages its sources with fixed timestamps, reports dependencies, and disassembles
its methods:

```sh
(cd e2e/integration && bazel build :javadoc :source_archive :dependencies :bytecode)
```

Outputs live under `e2e/integration/bazel-bin/`: `javadoc_html/`,
`javadoc-javadoc.jar`, `source_archive.jar`, `dependencies.txt`, and `bytecode.txt`.
Use `jar = False` on `elide_javadoc` when only HTML is needed. Use the default
theme with Elide 1.6.2.

## Generate Java bindings for a C API

The same workspace declares both `sample/api.h` and its included `types.h`:

```sh
(cd e2e/integration && bazel build :bindings --output_groups=+sources)
```

`bindings.srcjar` contains `sample.bindings.Api`; `bindings_sources/` exposes the
individual generated files. Add the source jar to a Java compilation using a
JDK supporting FFM (22+). Declare every included header and target-specific
sysroot input; the rule does not discover a cross-compilation SDK for you.

## Adopt Elide in an existing rules_kotlin project

The [KotlinBuilder sample](../e2e/kotlin_builder/BUILD.bazel) registers the adapter,
then uses normal `kt_jvm_library` targets. `annotated` uses KAPT to generate a
Java class; `symbols` uses a KSP2 provider to generate Kotlin and a resource:

```sh
./tools/verify_integrations.sh kotlin
```

The same workspace demonstrates standalone `elide_kapt` and `elide_ksp` source
jars. Prefer the integrated plugin path when generated sources must participate
in the same Kotlin target. See [the adapter guide](kotlin_builder.md) for the
supported request shapes and fallback rules.

## Run existing Python binaries and tests on Elide

Follow [the Python setup](python.md) to select the overlay/runtime, then use
ordinary rules_python targets:

```python
load("@rules_python//python:py_binary.bzl", "py_binary")
load("@rules_python//python:py_library.bzl", "py_library")
load("@rules_python//python:py_test.bzl", "py_test")

py_library(name = "library", srcs = ["library.py"], data = ["message.txt"])
py_binary(name = "app", srcs = ["app.py"], deps = [":library"])
py_test(name = "app_test", srcs = ["app_test.py"], deps = [":library"])
```

The [Python sample](../e2e/python_overlay/BUILD.bazel) adds a transitive library,
checks resource access and subprocesses, and verifies an explicitly requested
Python 3.11 target selects a different runtime:

```sh
(cd e2e/python_overlay && bazel run :app -- "space argument" --flag)
./tools/verify_integrations.sh python
```

The app prints `Elide Python runfiles ['space argument', '--flag']`. The shell
bootstrap verification runs with no Python on PATH and invalid ambient
virtualenv settings. Pure-Python dependencies are the initial supported scope;
this does not demonstrate native wheel compatibility.

## Build C without a host compiler

`elide_cc_binary` compiles and links with the LLVM toolchain bundled in Linux
Elide distributions ([details](c.md)):

```sh
(cd e2e/cc && bazel run :hello)
./tools/verify_integrations.sh cc
```

The program prints `hello from elide cc: sqrt(1764)=42 args=0`.

## Diagnose dependency use and validate pruning

```sh
./tools/verify_integrations.sh jvm
```

The sample `uses_one_dep` target declares two dependencies but uses one. The
verifier checks that only the spare dependency appears in `.unused`. A second
experiment creates a temporary workspace and checks actual recompilation after
unused and used dependency ABI changes, without modifying the checkout.
