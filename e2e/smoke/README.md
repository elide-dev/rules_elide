# e2e/smoke

Standalone Bazel workspace consuming `rules_elide` via `local_path_override`.

## Analysis-only (default, CI-friendly)

Validates the rule graph without invoking the elide CLI:

```bash
bazel build //... --nobuild
```

Used in CI and as a default sanity check during development.

By default the workspace registers a no-op stub toolchain (`//:smoke_elide_toolchain`),
so analysis succeeds without a real Elide release.

## Execution mode with a local Elide build

Point the extension at an already-extracted Elide distribution with the
first-class `elide.use(local_path = ...)` tag — no env vars, no action wrapper.
In `MODULE.bazel`, replace the stub registration with:

```python
elide = use_extension("@rules_elide//elide:extensions.bzl", "elide")
elide.use(local_path = "/abs/path/to/elide")   # already-extracted distribution
use_repo(elide, "elide_toolchains")
register_toolchains("@elide_toolchains//:all")
```

Then run for real:

```bash
bazel build //...
bazel test  //...
```

`elide.use` also accepts a custom release (`version` + `url_template` +
per-platform `integrity`) — see `docs/extensions.md`. (This replaces the old
`ELIDE_DEV_BIN` / `--config=dev` wrapper.)
