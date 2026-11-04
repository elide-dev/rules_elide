#!/usr/bin/env python3
"""Verify actual ABI, processing, resource, and dependency-report outputs."""
from pathlib import Path
from zipfile import ZipFile

out = Path("bazel-bin")
for jar, entry in [
    ("annotated.jar", "proc/gen/AnnotatedGenerated.class"),
    ("symbols.jar", "sample/Generated.class"),
    ("kapt_sources.srcjar", "proc/gen/AnnotatedGenerated.java"),
    ("ksp_sources.srcjar", "sample/Generated.kt"),
]:
    with ZipFile(out / jar) as archive:
        assert entry in archive.namelist(), (jar, archive.namelist())
with ZipFile(out / "symbols.jar") as archive:
    assert archive.read("processor-result.txt") == b"from-ksp"
assert b"//:greeter" in (out / "greeter-kt.jdeps").read_bytes()
with ZipFile(out / "greeter-kt.abi.jar") as archive:
    assert any(name.endswith(".class") for name in archive.namelist())
print("Native ABI/jdeps, KAPT, and KSP2 generated outputs passed.")
