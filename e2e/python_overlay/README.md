# Python overlay smoke build

From this directory, run `bazel build //...` with Bazel 9.3.0.

The module installs the published Elide 1.6.2 base and matching Python overlay
with separate pinned checksums. The `:python` action runs Python inside the
Bazel sandbox using only `ElideToolchainInfo.python_tool_files`, imports standard
library modules, and checks the component marker. Its result is `bazel-bin/python.txt`.
The `:java` target verifies the replacement executable still compiles Java with
the smaller JVM compile input set.

No local `elide setup` or mutable environment is required. To use previously
downloaded archives, pass `--distdir=/path/to/archives`; retain the published
filenames for both the base and Python archives.

## rules_python adapter

This Linux x86_64 workspace also registers Elide as a Python 3.13 runtime.
Its `.bazelrc` selects the shell bootstrap, avoiding host Python at startup.

```sh
bazel test //:runtime_test //:versioned_test //:other_version_test
bazel run //:app -- "space argument" --flag
python3 verify_no_host_python.py
```

The tests cover transitive libraries, data runfiles, stdlib imports, `-m`,
subprocess argument and exit-code forwarding through `sys.executable`, and
selection of CPython for an explicitly requested different Python version.
The verification script launches the built binary/test with no Python on PATH
and with deliberately invalid ambient Python/virtualenv paths.

To exercise the legacy bootstrap (which requires host Python to start):

```sh
bazel test //:runtime_test --@rules_python//python/config_settings:bootstrap_impl=system_python
```

From the repository root, `./tools/verify_integrations.sh python` runs both
bootstrap modes and the no-host-Python check. It also invokes the manual
`:intentional_failure` target and checks that Bazel fails with the expected
Python assertion, rather than a launcher/setup error.
