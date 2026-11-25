# e2e/apidocs

Real-toolchain fixture for `elide_apidocs`. It builds
[elide-dev/doclet](https://github.com/elide-dev/doclet) from a pinned commit
(`doclet.BUILD.bazel`), documents three targets with it, and renders through
the Elide 1.6.2 binary:

- `fixture_docs`: a `///` Markdown comment, `{@inheritDoc}` of
  `Object.toString`, a theme, an offline JDK link, an excluded package, and a
  page path long enough to need a PAX tar header.
- `catalogue_docs`: a `rules_java` library whose public API returns a class an
  annotation processor generates. Its source jar includes the generated source,
  which is documented too.
- `catalogue_classpath_docs`: the same library compiled by `elide javac`, whose
  source jar holds only the handwritten class. The generated class resolves from
  the compile classpath and is not documented.

```sh
bazel build //... --remote_download_outputs=all
python3 verify_apidocs.py
```

Or run `./tools/verify_integrations.sh apidocs` from the repository root.
`.bazelrc` selects JDK 25 for compiling and running the doclet.

The doclet pin is the head of the open PR stack elide-dev/doclet#8 to #11.
Move it to doclet `main` once that stack merges.
