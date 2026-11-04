# OpenSSF improvement plan

Reviewed 2026-11-04. This repository does **not** claim a Best Practices badge,
a newly achieved Scorecard score, or SLSA certification.

[Scorecard](https://github.com/ossf/scorecard/blob/main/docs/checks.md) measures
repository/security practices. The [Best Practices badge](https://www.bestpractices.dev/en/criteria)
is a separate program with passing, silver, and gold criteria and evidence.
Adding a workflow cannot establish organizational or coverage requirements.

## Published baseline

The [Scorecard report](https://api.scorecard.dev/projects/github.com/elide-dev/rules_elide)
retrieved on 2026-11-04 was dated 2026-11-02, for commit
`a23452248460302fca0ec8b93a8a76f8f9359cc1`, with a **7.9/10** score. It reported
Best Practices and fuzzing at 0, maintenance and branch protection at 5, and
review/SAST at 9. Several workflow-related checks were inconclusive (`-1`),
including “no workflows found.” Those are unknown results, not passing checks.

A likely cause is archive-mode scanning combined with `.github export-ignore`:
`git archive HEAD .github` produces no workflow entries. The Scorecard workflow
now requests `file_mode: git` so it can inspect those files. A future report may
expose new findings; this is an accuracy fix, not a promised score increase.

## Implemented in the repository

| Area | Evidence | Limitation |
| --- | --- | --- |
| Update automation | `.github/dependabot.yml`, `.github/renovate.json`, `requirements-dev.txt` | Renovate needs app access; embedded Elide components and hashes remain manual |
| CI security | Read-only workflow defaults, pinned actions, nonpersistent checkouts, zizmor/ShellCheck | Two documented BCR tag-ref exceptions; privileged release jobs remain necessary |
| Reporting | `SECURITY.md`, private reporting address, issue templates | Response targets require operational follow-through |
| Review and governance | `GOVERNANCE.md`, `CODEOWNERS`, PR template, code of conduct | Files do not prove independent review or reviewer availability |
| Architecture and boundaries | `docs/architecture.md`, `docs/security-model.md`, `AGENTS.md` | Threat model is not an independent audit |
| Testing | `docs/testing.md`, shared integration runner, compiler/runtime regression checks | Passing test counts are not measured statement/branch coverage |
| Delivery | Release archives, SPDX SBOM, attestation workflow | Verification must be exercised against published artifacts; no blanket reproducibility claim |
| Monitoring | Weekly/main Scorecard publication; scheduled workflow analysis | No claimed score until the service reports the relevant commit |

CodeQL is deliberately absent. Do not enable it to satisfy a score suggestion.
The replacement static checks are scoped honestly in the security model.

## Hosted configuration snapshot and maintainer follow-up

Read-only GitHub API inspection found Dependabot security updates, secret
scanning, and secret-scanning push protection enabled. The default Actions token
is read-only, but Actions can approve PR reviews. A default-branch ruleset is
active with review/check requirements and an organization-admin bypass; a second
ruleset named `main` is disabled. CodeQL default setup is not configured.

Review these settings as an administrator; they were not changed by this work:

1. Reconcile required check names with checks actually produced by current CI.
   Verify the existing external check contexts before removing or replacing them.
2. Decide the intended admin/direct-push exception and independent review policy.
   The maintainer currently permits direct commits to main; tightening bypasses
   must be an explicit change, not an incidental scoring exercise.
3. Consider disabling Actions' ability to approve pull requests. Confirm release
   automation requirements first; a bot approval is not independent human review.
4. Confirm Renovate installation/access, alert triage ownership, organization MFA,
   a second release-capable maintainer, and credential-recovery procedures.
5. Upload `docs/assets/rules_elide-social-banner.png` as the hosted social preview.
   A committed image does not set the GitHub repository preview.
6. Enroll/locate the project on bestpractices.dev and attach evidence. Add a badge
   to the README only after the actual project status can be linked.

## Path toward the metal badges

For [silver](https://www.bestpractices.dev/en/criteria/1), establish passing status,
verify access continuity, and adopt a reviewed one-year roadmap. Documentation
and policies added here are supporting material, not proof of operations.

For [gold](https://www.bestpractices.dev/en/criteria/2), the major outstanding
items include silver status; a bus factor of at least two; two unassociated
significant contributors; MFA; per-file copyright/license statements; independent
review of at least half of proposed modifications before release; reproducible
build evidence; measured 90% statement and 80% branch coverage where applicable;
a security review within five years; and pre-release dynamic analysis.

Audit license/header coverage without inventing copyright ownership. Measure
Kotlin/worker and helper coverage first, explain tool limitations for Starlark,
and add fuzz/property tests around protocol parsing and path handling. Test
reproducibility with independent clean builds before making a project-wide claim.
Document actual reviewers, findings, remediation, and release evidence rather
than checking off criteria on the strength of this plan.

## Useful starter contributions

- Add a real custom-doclet fixture with declared resources.
- Exercise Python pure-Python package imports from a locked dependency fixture.
- Add mixed Java/Kotlin cache-invalidation coverage matching the Java experiment.
- Add adversarial response-file/path inputs to KotlinBuilder tests.
- Audit missing source headers while preserving upstream/generated attribution.

Confirm the scope in an issue before undertaking a large migration. See
[CONTRIBUTING.md](../CONTRIBUTING.md) for tests and contribution expectations.
