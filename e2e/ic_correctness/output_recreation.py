#!/usr/bin/env python3
"""Require complete IC output after Bazel-style output-directory recreation."""
import argparse
from pathlib import Path
import shutil
import subprocess
import tempfile


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--elide", required=True, type=Path)
    args = parser.parse_args()
    elide = str(args.elide.resolve())
    with tempfile.TemporaryDirectory(prefix="elide-ic-output-") as directory:
        work = Path(directory)
        (work / "A.kt").write_text("package probe\nobject A { fun value(): Int = 1 }\n")
        (work / "B.kt").write_text("package probe\nobject B { fun value(): Int = 2 }\n")

        def compile_to(cache, output):
            subprocess.run([elide, "kotlinc", "--incremental", "--incremental-cache-dir", cache,
                            "--", "-module-name", "probe", "-d", output, "A.kt", "B.kt"],
                           cwd=work, check=True)

        def contents(output):
            return {p.relative_to(output): p.read_bytes() for p in output.rglob("*") if p.is_file()}

        compile_to("cache", "classes")
        assert (work / "classes/probe/B.class").is_file(), "Cold build omitted B"
        (work / "A.kt").write_text("package probe\nobject A { fun value(): Int = 3 }\n")
        # Only this test-owned output is removed; preserve the independent IC cache.
        shutil.rmtree(work / "classes")
        (work / "classes").mkdir()
        compile_to("cache", "classes")
        compile_to("fresh-cache", "fresh-classes")
        actual = contents(work / "classes")
        expected = contents(work / "fresh-classes")
        missing = sorted(map(str, expected.keys() - actual.keys()))
        if actual != expected:
            raise AssertionError(f"Recreated IC output differs from clean output; missing: {missing}")
        print("Recreated IC output matches clean output")


if __name__ == "__main__":
    main()
