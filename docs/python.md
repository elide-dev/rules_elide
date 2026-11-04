# Python runtime integration

`register_elide_python_toolchain` connects the pinned Python overlay to ordinary
`rules_python` targets. Existing `py_library`, `py_binary`, and `py_test` targets
can keep their sources, dependencies, and data declarations.

## Setup

In `MODULE.bazel`:

```python
bazel_dep(name = "rules_python", version = "1.7.0")
bazel_dep(name = "platforms", version = "1.1.0")

elide = use_extension("@rules_elide//elide:extensions.bzl", "elide")
elide.install(version = "1.6.2", python = True)
use_repo(elide, "elide_linux_amd64")
register_toolchains("//:elide_py")
```

In `BUILD.bazel`:

```python
load("@rules_elide//elide/python:toolchain.bzl", "register_elide_python_toolchain")

register_elide_python_toolchain(
    name = "elide_py",
    elide = "@elide_linux_amd64//:bin/elide",
    runtime_files = "@elide_linux_amd64//:elide_python_files",
    target_compatible_with = ["@platforms//os:linux", "@platforms//cpu:x86_64"],
)
```

In `.bazelrc`:

```text
build --@rules_python//python/config_settings:python_version=3.13
build --@rules_python//python/config_settings:bootstrap_impl=script
```

The shell bootstrap avoids requiring host Python to start the program. Set the
language version explicitly: rules_python otherwise supplies its own default,
which may select a different runtime. The adapter matches `3.13` (and an unset
version flag), and leaves other versions to other registered toolchains. Exact
patch-version selection is not advertised by this adapter.

Define one adapter per supported target platform, using matching distribution
labels and OS/CPU constraints. These are **target** runtime files, not files
selected for the build machine. The macro declares targets; registration happens
in `MODULE.bazel`. The overlay component marker is checked during analysis.

## Behavior and boundaries

The launcher carries the distribution in runfiles, disables user site packages
and bytecode writes, clears ambient virtualenv/runtime selection, and retains only
runfiles paths from `PYTHONPATH`. It points `sys.executable` at the launcher so
Python subprocesses use the same runtime. Elide 1.6.2 misreports `safe_path` when
`PYTHONSAFEPATH` is set; the launcher clears that variable so rules_python's
bootstrap removes the script-directory entry correctly.

Pure-Python sources and ordinary `PyInfo` dependencies are the initial supported
scope. Dependency resolution remains with rules_python: this adapter does not run
pip or uv during build/test actions or promise compatibility with CPython native
wheels. Native extensions, coverage, precompiled bytecode, and zip executables
need separate validation. Use source-based targets with precompilation disabled.

The launcher requires Bash and standard POSIX tools. Linux x86_64 is covered by
the real-runtime fixture; macOS and remote execution need additional validation.
Windows and manifest-only distribution layouts are not supported yet.

See [the fixture](../e2e/python_overlay/README.md) and
[the generated API reference](python_toolchain.md).
