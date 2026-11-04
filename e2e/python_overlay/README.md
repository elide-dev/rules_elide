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
