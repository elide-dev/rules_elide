# Security model and review boundaries

This is a documented threat model, not an independent security audit. Report
vulnerabilities privately using [SECURITY.md](../SECURITY.md).

## Assets and trust boundaries

| Boundary | What is trusted | Controls and limits |
| --- | --- | --- |
| Repository resolution | Pinned Elide archives and upstream dependency registries | Base/overlay SRI hashes, explicit versions, declared repository inputs; `local_path` trusts the supplied distribution |
| Build execution | Compilers, source code, processors, plugins, headers, doclets | Declared inputs and Bazel execution policy; these components can execute code and are not made safe by the rules |
| Kotlin worker | Requests from Bazel, compiler outputs, fallback worker | Protocol tests, explicit routing, compiler failures propagated; resident workers require trusted build inputs |
| Python runtime | Overlay, sources, dependencies, native libraries | Runfiles closure, no ambient virtualenv/home, constrained PYTHONPATH, no user site; no general CPython native-wheel guarantee |
| Cache/RBE | Configured cache and executor operators | Consumer controls credentials and trust; repository test coverage does not prove every rule works on every executor |
| CI contributions | Proposed source and workflow changes | Read-only defaults, hosted runners for untrusted contributions, nonpersistent checkout credentials, no pull_request_target execution |
| Releases | Maintainers, release credentials, reusable workflow publishers | Draft publication sequence, scoped job permissions, provenance and SBOM assets; upstream and account compromise remain risks |

Review especially changes to shell interpolation, response-file parsing,
archive paths, resource discovery, input pruning, environment forwarding, and
worker lifetime. Attackers could aim to execute code with publishing credentials,
poison a cache, substitute a toolchain, or make downstream compilation reuse an
incorrect ABI. Reproduce failures without secrets and preserve useful evidence.

## CI and scanner choices

CodeQL is not enabled by this repository. `security.yml` runs zizmor workflow
analysis, ShellCheck on release/integration entrypoints, and policy/SBOM tests.
Other lint checks include actionlint, buildifier, and secret detection through
pre-commit. These are useful static checks, not a complete Kotlin/Python SAST
program or an assurance that dependencies have no vulnerabilities.

Dependabot owns Actions and Python requirements; Renovate owns Bazel modules,
Bazelisk, and pre-commit hooks. Security updates still require human triage.
Custom Elide pins and embedded compiler components need explicit review; the
update bots do not discover every embedded dependency. Scorecard publishes JSON
results and an Actions artifact without CodeQL or a code-scanning upload step.
It uses Git fetch mode because source archives intentionally omit `.github`.

The self-hosted benchmark job and the self-hosted macOS test job (`macos-arm64-cipool`)
accept main pushes and same-repository PRs only.
That excludes forks, but trusted contributors can still change executable code.
Keep that runner isolated from production systems and secrets; replace it with
ephemeral infrastructure if the contributor trust model changes.

## Reusable workflow pin exceptions

Ordinary action uses must have a full commit SHA. Two release calls retain tags:

- `bazel-contrib/.github/.github/workflows/release_ruleset.yaml@v7.7.0`
- `bazel-contrib/publish-to-bcr/.github/workflows/publish.yaml@v1.6.0`

The existing BCR publication flow relies on tag-ref builder identities in its
attestations; changing to a raw SHA previously made verification reject the ref.
The exceptions are individually annotated for zizmor and tested by an explicit
allowlist. They retain upstream tag-mutation risk and may reduce Scorecard's
Pinned-Dependencies result. Revisit only with an end-to-end BCR provenance test;
do not conceal the exceptions to inflate the score.

The release tag push authenticates through a command-scoped Git credential
helper. It does not persist the publishing PAT in the checkout. Tag signing is
conditional on the configured GPG key; do not describe every tag as signed.

## Review and incident follow-up

For a security-sensitive change, request independent human review and record the
reproduction, boundary, mitigation, tests, and remaining limitations. Rotate
exposed credentials and investigate affected artifacts/caches after a compromise.
Do not use this document as evidence that a formal review or incident drill has
already occurred. [OpenSSF follow-up](openssf.md) tracks those outstanding items.
