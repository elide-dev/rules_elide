# Governance

rules_elide is maintained in the [elide-dev organization](https://github.com/elide-dev).
The current primary maintainer and release administrator is
[Sam Gammon (@sgammon)](https://github.com/sgammon).
[CODEOWNERS](.github/CODEOWNERS) routes review requests; it does not by itself
prove that a change received review.

## Responsibilities and decisions

Contributors propose changes through issues and pull requests, include relevant
tests/documentation, and disclose compatibility or security implications.
Maintainers review correctness, API stability, testing, dependency changes, and
release readiness. The primary maintainer resolves disagreements after allowing
contributors to explain alternatives. Discuss substantial public API or security
boundary changes in an issue or design document before committing to an approach.

Release administrators manage publishing credentials, release tags, attestations,
and BCR publication. Security reports are handled privately under
[SECURITY.md](SECURITY.md). Use [the code of conduct](CODE_OF_CONDUCT.md) for
participation expectations and conduct reports.

## Review expectations

Prefer review by another human for production changes, particularly CI/release
credentials, downloads, executable launchers, worker protocols, and ABI/pruning
logic. Reviewers check the problem, correctness, declared inputs, failure paths,
compatibility, tests, documentation, and least-privilege effects. Changes should
pass their applicable checks before release. Bot or AI review is supplementary.

Maintainer-authorized direct commits and administrative bypasses remain possible;
this repository does not claim every change has independent review. Before a
release, review those changes and record the reviewer and findings in the release
PR. Measure actual review coverage before claiming an OpenSSF review criterion.

## Continuity and access

Maintainers should use phishing-resistant MFA, individual accounts, and scoped
credentials. A second release-capable maintainer and recovery procedure remain
items to verify before claiming continuity or a bus factor of two. Do not publish
recovery codes or credentials as evidence. Changes to required reviews, bypasses,
and release access need an explicit maintainer decision.
