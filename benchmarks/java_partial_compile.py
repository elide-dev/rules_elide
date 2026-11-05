#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0
"""Probe ABI-gated partial Java compilation on isolated Commons Lang sources.

This is a compiler experiment, not an incremental Java rule. Source/output
ownership is deliberately restricted to the known Commons Lang public classes
and their nested classes. Every partial result must match a fresh full compile.
"""
import argparse
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import zipfile

import commons_lang_fixture
from pgo.gen_workrequest import check_responses, request


def classes(path):
    with zipfile.ZipFile(path) as archive:
        return {name: archive.read(name) for name in archive.namelist() if name.endswith(".class")}


def compile_request(worker, arguments, inputs):
    worker.stdin.write(request(arguments, inputs))
    worker.stdin.flush()
    prefix, size = b"", 0
    for shift in range(0, 70, 7):
        byte = worker.stdout.read(1)
        if not byte:
            raise RuntimeError("Compiler worker closed before responding")
        prefix += byte
        size |= (byte[0] & 127) << shift
        if byte[0] < 128:
            break
    else:
        raise RuntimeError("Invalid compiler response length")
    check_responses(prefix + worker.stdout.read(size), 1)



def boundary_probes(worker, work):
    """Check compile-time dependencies and expose the filename ownership limit."""
    source = work / "Api.java"
    options = ["--", "--release", "21", "-proc:none"]
    cases = (
        ("package_constant", "static final int K = 1;", "static final int K = 2;", True),
        ("package_method", "static int value() {return 1;}",
         "static long value() {return 1;}", True),
        ("private_constant", "private static final int K = 1;",
         "private static final int K = 2;", False),
        ("private_nested_delete", "private static class Hidden {}", "", False),
    )
    report = []
    for name, before, after, expected in cases:
        headers = []
        for index, body in enumerate((before, after)):
            source.write_text("package probe; public class Api {" + body + "}")
            jar = work / f"{name}-{index}.jar"
            compile_request(worker, ["--abi-only", "--jar", str(jar), *options,
                                    str(source)], [source])
            headers.append(classes(jar))
        changed = headers[0] != headers[1]
        if changed != expected:
            raise AssertionError(f"Unexpected ABI boundary for {name}: {changed}")
        report.append({"scenario": name, "abi_changed": changed})

    # Api.java also owns Helper and Helper$Hidden. Removing only Api and Api$*
    # leaves a stale class even though the whole-module header is unchanged.
    outputs, headers = [], []
    for index, body in enumerate(("private static class Hidden {}", "")):
        source.write_text("package probe; public class Api {} class Helper {" + body + "}")
        jar, header = work / f"ownership-{index}.jar", work / f"ownership-{index}-abi.jar"
        compile_request(worker, ["--jar", str(jar), "--emit-abi", str(header),
                                *options, str(source)], [source])
        outputs.append(classes(jar))
        headers.append(classes(header))
    if headers[0] != headers[1]:
        raise AssertionError("Private secondary-class deletion unexpectedly changed ABI")
    naive = {name: value for name, value in outputs[0].items()
             if name != "probe/Api.class" and not name.startswith("probe/Api$")}
    naive.update(outputs[1])
    stale = sorted(naive.keys() - outputs[1].keys())
    if stale != ["probe/Helper$Hidden.class"]:
        raise AssertionError(f"Expected secondary-class ownership counterexample: {stale}")
    report.append({"scenario": "secondary_nested_delete", "abi_changed": False,
                   "filename_merge_stale_classes": stale})
    return report


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--commons-lang", type=Path, required=True)
    parser.add_argument("--elide", default=os.environ.get("ELIDE", "elide"))
    parser.add_argument("--output", type=Path, help="Optional JSON correctness report")
    args = parser.parse_args()
    binary = shutil.which(args.elide)
    if not binary:
        parser.error("Elide executable not found")
    production, metadata = commons_lang_fixture.snapshot(args.commons_lang)
    report = {"source_workload": metadata, "cases": []}
    with tempfile.TemporaryDirectory(prefix="elide-java-partial-") as directory:
        work = Path(directory)
        sources = {work / "src" / name: contents.decode("utf-8") for name, contents in production.items()}
        for path, contents in sources.items():
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text(contents)
        with subprocess.Popen([binary, "--safe-close", "javac", "--persistent_worker"],
                              stdin=subprocess.PIPE, stdout=subprocess.PIPE,
                              env=dict(os.environ, ELIDE_BAZEL="1")) as worker:
            try:
                options = ["--", "--release", "21", "-proc:none"]
                paths = list(map(str, sources))
                inputs = list(sources)
                compile_request(worker, ["--jar", str(work / "baseline.jar"), "--emit-abi",
                    str(work / "baseline-abi.jar"), *options, *paths], inputs)
                baseline, abi = classes(work / "baseline.jar"), classes(work / "baseline-abi.jar")
                for scenario in ("body", "private_member", "multi_file_body", "internal_module_api"):
                    for path, contents in sources.items():
                        path.write_text(contents)
                    commons_lang_fixture.mutate(sources, scenario, 1)
                    changed = [path for path, contents in sources.items() if path.read_text() != contents]
                    compile_request(worker, ["--abi-only", "--jar", str(work / "changed-abi.jar"),
                        *options, *paths], inputs)
                    unchanged = classes(work / "changed-abi.jar") == abi
                    expected = scenario != "internal_module_api"
                    if unchanged != expected:
                        raise AssertionError(f"Unexpected ABI boundary for {scenario}: {unchanged}")
                    row = {"scenario": scenario, "changed_sources": [p.name for p in changed],
                           "abi_unchanged": unchanged, "partial_compilation": unchanged}
                    if unchanged:
                        compile_request(worker, ["--jar", str(work / "partial.jar"), *options,
                            "-sourcepath", "", "-classpath", str(work / "baseline.jar"),
                            *map(str, changed)], changed + [work / "baseline.jar"])
                        compile_request(worker, ["--jar", str(work / "reference.jar"),
                            *options, *paths], inputs)
                        # This naming convention is specific to these fixture sources. A general
                        # implementation must track every emitted class's originating source.
                        prefixes = [p.relative_to(work / "src").with_suffix("").as_posix() for p in changed]
                        merged = {name: contents for name, contents in baseline.items()
                                  if not any(name == prefix + ".class" or name.startswith(prefix + "$")
                                             for prefix in prefixes)}
                        merged.update(classes(work / "partial.jar"))
                        reference = classes(work / "reference.jar")
                        differences = sorted(name for name in merged.keys() | reference.keys()
                                             if merged.get(name) != reference.get(name))
                        if differences:
                            raise AssertionError(f"Partial/full mismatch for {scenario}: {differences}")
                        row["verified_class_files"] = len(reference)
                    report["cases"].append(row)
                    print(json.dumps(row), flush=True)
                report["boundary_cases"] = boundary_probes(worker, work)
                print(json.dumps({"boundary_cases": report["boundary_cases"]}), flush=True)
            finally:
                worker.stdin.close()
                try:
                    worker.wait(timeout=30)
                except subprocess.TimeoutExpired:
                    worker.kill()
                    worker.wait()
            if worker.returncode:
                raise RuntimeError(f"Compiler worker exited with {worker.returncode}")
    if args.output:
        args.output.write_text(json.dumps(report, indent=2) + "\n")


if __name__ == "__main__":
    main()
