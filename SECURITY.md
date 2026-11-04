# Security policy

## Reporting a vulnerability

Email **security@elide.dev** rather than opening a public issue. Include the
rules_elide commit/release, Elide version, Bazel version, affected platform,
minimal reproduction, expected security boundary, and potential impact. Do not
include live credentials or private customer data.

We aim to acknowledge reports within **72 hours** and provide a remediation plan
within **14 days**. These are response targets, not guaranteed fix deadlines.
If you receive no acknowledgement, follow up on the same email thread.

Maintainers assess impact, reproduce the issue, identify affected versions, and
coordinate a fix and regression test with the reporter and affected upstreams.
We agree a disclosure timeline based on severity, exploitation, and remediation
readiness. Once a fix or mitigation is available, publish affected versions,
upgrade instructions, and an advisory where appropriate. Credit reporters unless
they request anonymity. Keep exploit details private while remediation proceeds.

## Supported versions and updates

Report vulnerabilities against any version. Fixes normally target `main` and the
latest release; older release lines do not have a guaranteed backport window.
Users should plan to upgrade to the latest fixed release. Check
[releases](https://github.com/elide-dev/rules_elide/releases) and
[security advisories](https://github.com/elide-dev/rules_elide/security/advisories)
for published information. An Elide runtime issue may also require a new compiler
or Python overlay pin; a rules-only update does not patch an older runtime binary.

## Security boundaries

The rules verify pinned downloaded distributions and declare action inputs for
Bazel execution. They do **not** make untrusted source, processors, doclets,
Python packages, native libraries, or BUILD files safe to execute. Build those
in isolated environments without production credentials. A Bazel sandbox is
not a complete boundary against malicious build code.

Local distributions and custom URLs are trust decisions made by the consumer.
Remote executors, caches, package registries, and CI actions are also part of the
build trust chain. See [the security model](docs/security-model.md) for details,
known exceptions, and [the OpenSSF plan](docs/openssf.md) for unverified gaps.
