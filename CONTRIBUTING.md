# Contributing

Contributions are welcome.

## Workflow

1. Open an issue describing the change.
2. Fork, branch, commit using [Conventional Commits](https://www.conventionalcommits.org/) (`feat:`, `fix:`, `docs:`, `chore:`).
3. Locally green:
   - `bazel test //...`
   - `buildifier --lint=warn .`
4. Open a PR against `main`.

## DCO

By contributing, you certify that you have the right to submit your contribution under the project's [LICENSE](LICENSE) (Apache 2.0). Sign off your commits with `git commit -s`.
