# e2e/integration

Real-toolchain integration test: a standalone Bazel workspace that activates
the `elide` extension against the real Elide CDN (`nightly/latest`) and
exercises an end-to-end `elide_java_library` -> `elide_java_binary` chain.

The first `bazel build` downloads the elide binary (~500 MB), so this is
slower than the analysis-only smoke under `../smoke/` and is intended for
scheduled CI runs rather than every PR.

## Run locally

```bash
bazel build //...
bazel run //:app
```
