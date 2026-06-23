# IC correctness harness

Verifies `elide kotlinc --incremental` against the failure mode that matters:
**fast but silently stale** — where reusing cache state across edits yields
output that differs from a clean build.

## `run.sh` — incremental-vs-clean equivalence

Walks a sequence of full module snapshots and, at every step, asserts the
IC-reused output is **byte-identical to a fresh-cache build of the same
sources**. Both sides use the same code path (`--incremental`) and a pinned
`-module-name`, so the only variable is whether the cache carries prior-edit
state — any byte difference is an IC bug. (kotlinc output is deterministic, and
the IC path differs from a plain compile only in module-file naming, so
fresh-cache-IC — not a plain compile — is the oracle.)

Steps exercise the cases that catch real IC bugs: body-only change, a `const`
inlined into an *untouched* caller, an `inline` body inlined into an untouched
caller, a signature change with caller update, adding a file, and deleting a
file (stale `.class` must be removed).

```bash
ELIDE=/path/to/elide ./run.sh
```

Exits non-zero if any step diverges from its clean-build oracle.

> Note: the harness runs `elide` from an ancestor of the sources (sources under
> the CWD). This matches how Bazel runs compile actions (from the exec root) and
> sidesteps WHIPLASH#1113; the bug itself is guarded by `wl1113_regression.sh`.

## `wl1113_regression.sh` — guard for WHIPLASH#1113

Reproduces the trigger for #1113: one-shot `kotlinc --incremental` reuse spun in
a runaway loop when the **source file was not under the CWD**. Runs `elide` from
a non-ancestor directory and does a reuse compile under a hard timeout.

- reuse completes → bug FIXED → exit 0
- reuse times out → bug still reproduces → exit 1 (expected until #1113 lands)

```bash
ELIDE=/path/to/elide ./wl1113_regression.sh
```

Fixed in `elide 1.3.3+15c568841`; this guard turns red if it regresses.
