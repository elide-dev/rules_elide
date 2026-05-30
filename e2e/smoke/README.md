# e2e/smoke

Standalone Bazel workspace consuming `rules_elide` via `local_path_override`.

## Analysis-only (default, CI-friendly)

Validates the rule graph without invoking the elide CLI:

```bash
bazel build //... --nobuild
```

Used in CI and as a default sanity check during development.

## Execution mode with a locally-built elide binary

Wires a locally-built elide binary into the smoke toolchain through the
`ELIDE_BIN` env var. The action wrapper execs into that binary when
`--config=dev` propagates the var into the action environment.

```bash
ELIDE_BIN=/abs/path/to/elide bazel build //... --config=dev
ELIDE_BIN=/abs/path/to/elide bazel test  //... --config=dev
```

When `ELIDE_BIN` is unset or not executable, the wrapper falls back to a
no-op (exit 0), so the workspace stays analysis-clean without any
elide-side support.
