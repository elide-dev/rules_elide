#!/usr/bin/env python3
"""Verify outputs after the JVM-tool and metadata smoke builds in README.md."""
from pathlib import Path
from zipfile import ZipFile

out = Path("bazel-bin")
with ZipFile(out / "source_archive.jar") as jar:
    assert {"Hello.java", "Main.java"}.issubset(jar.namelist())
    assert all(entry.date_time == (1980, 1, 1, 0, 0, 2) for entry in jar.infolist())
with ZipFile(out / "javadoc-javadoc.jar") as jar:
    assert "sample/Hello.html" in jar.namelist()
    assert all(entry.date_time == (1980, 1, 1, 0, 0, 2) for entry in jar.infolist())
with ZipFile(out / "bindings.srcjar") as jar:
    assert "sample/bindings/Api.java" in jar.namelist()
    assert b"sample_add" in jar.read("sample/bindings/Api.java")
assert "greet" in (out / "bytecode.txt").read_text()
assert "java.base" in (out / "dependencies.txt").read_text()
assert b"uses_one_dep" in (out / "uses_one_dep_classes.jar.jdeps").read_bytes()
unused = (out / "uses_one_dep.unused.txt").read_text().splitlines()
# The header is `<name>_abi.jar` with ABI compile avoidance (the default) and `<name>-ijar.jar` without.
assert any(path.endswith(("spare_abi.jar", "spare-ijar.jar")) for path in unused), unused
assert not any(path.endswith(("lib_abi.jar", "lib-ijar.jar")) for path in unused), unused
print("JVM tools, reproducible archives, and unused-dependency reporting passed.")
