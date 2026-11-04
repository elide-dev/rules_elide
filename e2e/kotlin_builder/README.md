# KotlinBuilder native integration smoke tests

The toolchain selects Elide 1.6.2, Kotlin language/API 2.4, JVM 21, and ABI jars.

```sh
bazel build :greeter :annotated :symbols :kapt_sources :ksp_sources \
  --output_groups=+generated_classes,+stubs
python3 verify_outputs.py
```

This executes native ABI/jdeps emission, KAPT through KotlinBuilder, the separate
KSP2 worker adapter, and the standalone `elide_kapt`/`elide_ksp` rules. Generated
sources are used by subsequent compilations; the verifier checks generated
classes, source jars, and KSP resources. Add `--distdir=/path/to/archives` to reuse
a downloaded Elide release. The fixture currently selects Linux AMD64 explicitly.
