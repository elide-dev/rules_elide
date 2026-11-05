# Working in rules_elide

Read [CONTRIBUTING.md](CONTRIBUTING.md) for commands and
[docs/architecture.md](docs/architecture.md) for the implementation map.
These instructions apply to this repository, including nested example workspaces.

## Scope and ownership

- Preserve unrelated working-tree changes. Do not add local diagnosis notes,
  credentials, downloaded distributions, or Bazel outputs to commits.
- Follow the maintainer's requested branch/commit workflow. Do not push, publish,
  open external issues, or alter repository settings without task authorization.
- Make changes reviewable and use Conventional Commits. AI assistance does not
  substitute for independent human review or substantiate security badge claims.

## Implementation contracts

- Native rules live in `elide/rules/`; shared compiler actions in
  `elide/private/compile_common.bzl`; public exports in `elide/defs.bzl`.
- KotlinBuilder is a worker/protocol adapter, not just a compiler CLI wrapper.
  Keep native and legacy/fallback routing tests when changing request handling.
- Python is an opt-in rules_python runtime. Keep target-platform files distinct
  from execution-platform compiler tools. Do not use host virtualenvs or run
  package installers from build/test actions.
- Declare every compiler, processor, doclet, header, and runtime input. ABI and
  pruning changes need real output/cache checks, not only argv assertions.
- Never invent checksums or release versions. Keep base/overlay versions aligned.
  `elide.use(local_path=...)` consumes an existing distribution without editing it.

## Validation

- Analysis only: `bazel test //tests:all --extra_toolchains=//tests:_test_elide_toolchain`.
- Full root: `bazel test //... --java_runtime_version=remotejdk_21 --tool_java_runtime_version=remotejdk_21`.
- Real fixtures: `./tools/verify_integrations.sh jvm|kotlin|python` (choose one,
  or use `all`). Never run execution tests with the stub toolchain.
- Public API changes: update examples, `bzl_library`/Stardoc deps, and regenerate
  references with `./tools/update_docs.sh`. Do not hand-edit generated API tables.
- Workflow/security changes: install `requirements-dev.txt`, run
  `zizmor --offline --format plain .github/workflows` and
  `python -m pytest tools/repository_policy_test.py tools/sbom_enrich_test.py`.
- Performance work: run `python3 -m unittest discover -s benchmarks -p "*_test.py"`.
  Preserve raw samples and regressions; compare supported stock optimization modes.
  See `benchmarks/PERFORMANCE_TARGETS.md` before claiming a performance win.
- Run relevant checks once, then repeat only for changes or unresolved failures.
  Report what was actually validated and any remaining limitations.

## Security and releases

- Do not enable CodeQL. The selected workflow analyzer is zizmor; Scorecard
  publishes its own results without a CodeQL action.
- Keep workflows read-only by default, do not persist checkout credentials, and
  do not introduce `pull_request_target` execution of contribution code.
- Pin actions to full commit SHAs. The two BCR reusable-workflow tag exceptions
  are documented in [docs/security-model.md](docs/security-model.md); do not
  silently SHA-pin them and break provenance verification.
- Do not weaken tests, integrity checks, or publishing boundaries to improve a
  score. Describe OpenSSF requirements as gaps until evidence supports them.
- Refer vulnerability reports to [SECURITY.md](SECURITY.md). Never put exploit
  details, tokens, or private reports in public issues or logs.

## Documentation and assets

The README is the entry point; task guides belong under `docs/`. Keep test
coverage claims in `docs/testing.md` consistent with CI. Use supplied artwork
under `docs/assets/`; preserve accessible alt text and do not redraw logos.
