# BuildBuddy RBE for rules_elide — design

**Date:** 2026-06-24
**Status:** approved; implemented

## Goal

Configure rules_elide to build/test on **BuildBuddy** remote execution (RBE) +
remote cache + Build Event Stream, and add an **e2e RBE integration test** (Java +
Kotlin, compiled through the Elide toolchain) that exercises the path end-to-end in
CI. Elide + rules_elide already run under RBE in the HEATWAVE monorepo; this mirrors
that proven setup but swaps the custom Wolfi worker image for a **public BuildBuddy
image**. BuildBuddy is used "nearly everywhere" — CI builds/tests — **except the
inner benchmark loops**, which must stay local.

## Activation model

**CI-default, local opt-in** (rules_elide is a public ruleset; forcing RBE on by
default would break keyless/external-contributor builds). RBE/cache/BES live behind
`--config=remote`; CI passes it (with the key), local builds are local unless a dev
opts in with their own key. The benchmark workspaces never get the config.

## Components

### 1. Remote bazelrc profiles (root `.bazelrc`)
Three composable configs (mirroring HEATWAVE's `tools/bazelrc/remote.bazelrc`):

- `config:buildbuddy` — BES + remote cache:
  - `--bes_results_url=https://elide-dev.buildbuddy.io/invocation/`
  - `--bes_backend=grpcs://elide-dev.buildbuddy.io`
  - `--remote_cache=grpcs://elide-dev.buildbuddy.io`, `--remote_cache_compression`,
    `--remote_upload_local_results`, `--remote_timeout=3h`
- `config:rbe` — remote executor on top (`--config=buildbuddy` +):
  - `--remote_executor=grpcs://elide-dev.buildbuddy.io`
  - `--host_platform=//tools/platforms:rbe_linux_amd64`
  - `--extra_execution_platforms=//tools/platforms:rbe_linux_amd64`
  - `--jobs=50`
- `config:remote` — convenience alias for `--config=rbe` (the usual entrypoint).

The API key is **never committed**. `.bazelrc` already has `try-import
%workspace%/user.bazelrc`; the key is injected there as
`common --remote_header=x-buildbuddy-api-key=<KEY>` (HEATWAVE's mechanism), written
by CI from the `BUILDBUDDY_API_KEY` secret and by devs locally. `user.bazelrc` is
git-ignored.

### 2. RBE platform `//tools/platforms:rbe_linux_amd64`
A `platform()` with `constraint_values` `@platforms//os:linux` + `@platforms//cpu:x86_64`
and `exec_properties`:
- `OSFamily=Linux`, `Arch=amd64`
- `container-image=docker://gcr.io/flame-public/rbe-ubuntu20-04@sha256:036ae8c90876fa22da9ace6f8218e614f4cd500a154fc162973fff691e72d28e`
  (public BuildBuddy image, digest-pinned)
- `network=off` (`network`, not `dockerNetwork`, is the real BuildBuddy property
  name; the Elide binary ships to the executor as a tool input, so no network is
  needed at action time)
- `test.EstimatedMemory=1GB` (BuildBuddy's default sizing is too small for the JVM's
  `-Xms` reservation and trips `os::commit_memory` on JVM test actions)

No `rules_rs` parent (HEATWAVE needs it for Rust; we don't). The stock glibc image
suffices because the Elide toolchain already ships its native binary as an action
input (proven in HEATWAVE).

### 3. e2e RBE integration test (`e2e/rbe`)
A new standalone workspace, structured like `e2e/integration` but minimal and
RBE-configured:
- `MODULE.bazel` — `rules_elide` (local_path_override `../..`), `platforms`,
  `elide.install(channel = "nightly")`, elide toolchains registered, and
  `rules_jvm_external` (JUnit for the test).
- `BUILD.bazel` — `elide_java_library` (lib) + `elide_kotlin_library` (depends on the
  Java lib, proving cross-language) + an `elide_java_test` (JUnit) so RBE runs a test
  action too, plus an `elide_kotlin_binary` so a Kotlin binary link is exercised.
- `sample/` — small Java + Kotlin sources (copied from `e2e/integration`).
- `.bazelrc` — the integration base config + a `:ci` fragment + the
  `buildbuddy`/`rbe`/`remote` block + `try-import user.bazelrc`; `.bazelversion` 9.1.0.
- `//tools/platforms:rbe_linux_amd64` — its own copy of the platform target.

### 4. CI job `rbe (BuildBuddy)` (`.github/workflows/ci.yml`)
- Gated to **same-repo** events (`github.event_name == 'push'` or a same-repo PR) —
  the secret isn't available to fork PRs.
- Writes `user.bazelrc` with `common --remote_header=x-buildbuddy-api-key=$BUILDBUDDY_API_KEY`
  (to a file, never echoed; fails fast if the secret is empty).
- Runs `bazel test //... --config=remote --config=ci` in `e2e/rbe`.
- Bazel surfaces the BuildBuddy invocation URL (from `--bes_results_url`) in the log.

### 5. Benchmarks excluded
The benchmark workspaces (`benchmarks/`, `e2e/vanilla`, `e2e/integration`) get **no**
RBE config, and the CodSpeed harness already forces `--remote_executor=`
/`--remote_cache=`/`--disk_cache=` off — so inner loops never touch BuildBuddy.

## Notes / risks
- **glibc compatibility:** the Elide linux-amd64 binary needs glibc; `rbe-ubuntu20-04`
  (glibc 2.31) is compatible (HEATWAVE targets a 2.28 baseline).
- **Persistent workers vs RBE:** Elide's persistent kotlinc worker is a *local*
  optimization; under remote execution each compile runs as a standalone remote
  action. HEATWAVE confirms Elide compiles correctly that way; no rule change needed.
- **`network=off`:** relies on the Elide binary (and JDK) being declared action
  inputs shipped to the executor. If an Elide action needs network at runtime, this
  is where it would surface — the e2e/rbe test is exactly what catches it.
- **Endpoint:** `elide-dev.buildbuddy.io` (the org the repo is linked under).

## Out of scope
- Routing the existing `tests` / `integration` / `kotlin-builder` CI jobs through RBE
  (the config is available for them to adopt later; left local now so fork PRs work).
- A custom/hardened RBE image; macOS RBE; remote persistent workers.
