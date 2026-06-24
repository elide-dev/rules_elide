# e2e/rbe — BuildBuddy remote execution

End-to-end check that the Elide toolchain builds **and tests** on BuildBuddy
remote execution (RBE) + remote cache + Build Event Stream, across the
Java/Kotlin boundary.

The target graph is deliberately small:

```
lib (Java)  <-  kt_lib (Kotlin, depends on Java)  <-  kt_app (Kotlin binary)
lib (Java)  <-  HelloTest (JUnit test action)
```

so both a cross-language compile and a remote **test** action run on the
executor. The Elide native binary is shipped to the executor as an action input
(the public glibc image `gcr.io/flame-public/rbe-ubuntu20-04` is enough — no
custom worker image), which is why the RBE platform can set `network: off`.

## Running it

Remote needs a BuildBuddy API key, injected via `user.bazelrc` (git-ignored):

```sh
echo 'common --remote_header=x-buildbuddy-api-key=YOUR_KEY' > user.bazelrc
bazel test //... --config=remote
```

`--config=remote` turns on cache + execution + BES; the run prints a BuildBuddy
invocation URL. Without the key (or without `--config=remote`) the build runs
locally like any other e2e workspace.

`--config=remote`/`=rbe` pins both the host and execution platform to the
Linux/x86_64 RBE platform, so it expects a **Linux x86_64 build host** (CI
provides this). On another host (e.g. macOS) use `--config=buildbuddy` for
remote cache + BES only, which executes locally. Compiles run as one-shot
remote actions under RBE (Elide's persistent workers are a local-only
optimization, disabled by the `rbe` config).

CI runs this as the `rbe (BuildBuddy)` job (same-repo events only — the secret
is not exposed to fork PRs). See `.github/workflows/ci.yml` and the design at
`docs/superpowers/specs/2026-06-24-buildbuddy-rbe-design.md`.
