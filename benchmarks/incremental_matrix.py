#!/usr/bin/env python3
"""Measure edit propagation through a generated core -> facade -> clients -> app graph."""
import argparse
from collections import Counter
import json
import os
from pathlib import Path
import platform
import re
import shutil
import statistics
import subprocess
import tempfile
import time

REPO = Path(__file__).resolve().parents[1]
SCENARIOS = (
    "no_op", "comment", "body", "private_member", "internal_module_api",
    "public_module_api", "multi_file_body", "multi_module_body",
    "multi_module_api", "unused_dependency_api", "inline_or_constant",
)
MODES = ("vanilla", "elide", "elide_abi", "elide_pruned", "elide_incremental")
COMPILERS = {"Javac", "KotlinCompile", "ElideJavac", "ElideKotlinc"}


def positive(value):
    number = int(value)
    if number < 1:
        raise argparse.ArgumentTypeError("must be positive")
    return number


def json_entries(path):
    decoder = json.JSONDecoder()
    text = path.read_text()
    while text.strip():
        entry, end = decoder.raw_decode(text.lstrip())
        yield entry
        text = text.lstrip()[end:]


def source(language, package, name, expression="1", extra="", special=1):
    if language == "java":
        return (f"package {package}; public final class {name} {{\n"
                f"public static int value() {{ return {expression}; }}\n"
                f"public static final int MAGIC = {special};\n{extra}\n}}\n")
    return (f"package {package}\nobject {name} {{\n"
            f"fun value(): Int = {expression}\n"
            f"inline fun magic(): Int = {special}\n{extra}\n}}\n")


def fixture(work, language, mode, size, fanout):
    extension = "java" if language == "java" else "kt"
    rule = "java_library" if language == "java" else "kt_jvm_library"
    load = "@rules_java//java:defs.bzl" if language == "java" else "@rules_kotlin//kotlin:jvm.bzl"
    if mode != "vanilla":
        rule = f"elide_{'java' if language == 'java' else 'kotlin'}_library"
        load = "@rules_elide//elide:defs.bzl"
    sources = {}

    def target(package, name, classes, deps):
        directory = work / package
        directory.mkdir(exist_ok=True)
        build = directory / "BUILD.bazel"
        prefix = f'load("{load}", "{rule}")\npackage(default_visibility=["//visibility:public"])\n'
        stanza = f'{rule}(name={json.dumps(name)}, srcs={json.dumps([c + "." + extension for c in classes])}, deps={json.dumps(deps)})\n'
        build.write_text((build.read_text() if build.exists() else prefix) + stanza)
        for name, expression in classes.items():
            path = directory / f"{name}.{extension}"
            sources[path] = source(language, package, name, expression)

    target("core", "core", {f"Core{i}": str(i + 1) for i in range(size)}, [])
    target("spare", "spare", {"Spare": "1"}, [])
    special = "core.Core0.MAGIC" if language == "java" else "core.Core0.magic()"
    target("facade", "facade", {"Facade": f"core.Core0.value() + core.Core1.value() + {special}"}, ["//core", "//spare"])
    for i in range(fanout):
        target("clients", f"client{i}", {f"Client{i}": "facade.Facade.value()"}, ["//facade"])
    target("app", "app", {"App": " + ".join(f"clients.Client{i}.value()" for i in range(fanout))},
           [f"//clients:client{i}" for i in range(fanout)])
    return sources


def mutate(sources, scenario, language, nonce):
    extension = "java" if language == "java" else "kt"
    by_name = {path.name: path for path in sources}

    def change(name, kind):
        path = by_name[f"{name}.{extension}"]
        original = sources[path]
        if kind == "comment":
            changed = original + f"// edit {nonce}\n"
        elif kind == "body":
            if language == "java":
                changed = original.replace("return ", f"return {nonce} + ", 1)
            else:
                changed = original.replace("fun value(): Int = ", f"fun value(): Int = {nonce} + ", 1)
        elif kind in ("private", "public"):
            addition = (f"{kind} static int added{nonce}() {{ return {nonce}; }}" if language == "java"
                        else f"{kind} fun added{nonce}(): Int = {nonce}")
            index = original.rfind("}")
            changed = original[:index] + addition + "\n" + original[index:]
        else:
            changed = original.replace("MAGIC = 1;", f"MAGIC = {nonce + 1};") if language == "java" else original.replace("magic(): Int = 1", f"magic(): Int = {nonce + 1}")
        path.write_text(changed)

    edits = {
        "no_op": [], "comment": [("Core0", "comment")],
        "body": [("Core0", "body")], "private_member": [("Core0", "private")],
        "internal_module_api": [("Core0", "public")],
        "public_module_api": [("Facade", "public")],
        "multi_file_body": [(f"Core{i}", "body") for i in range(3)],
        "multi_module_body": [("Core0", "body"), ("Facade", "body")],
        "multi_module_api": [("Core0", "public"), ("Facade", "public")],
        "unused_dependency_api": [("Spare", "public")],
        "inline_or_constant": [("Core0", "special")],
    }
    for name, kind in edits[scenario]:
        change(name, kind)


def render(report):
    lines = ["# Incremental dependency-graph benchmark", "", f"Commit: `{report['commit']}`", "",
             "Times include Bazel invocation, analysis, compilation, and execution-log overhead.",
             "Shared action caches and remote execution are disabled. Every edit starts from a rebuilt pristine graph.",
             "Warm-ups are discarded. Counts include full source compiler actions only; ABI/header actions are reported separately.", "",
             "| Language | Mode | Edit | Mean (s) | Median (s) | Stddev (s) | Full compile targets per sample |",
             "| --- | --- | --- | ---: | ---: | ---: | --- |"]
    for row in report["results"]:
        times = [sample["seconds"] for sample in row["samples"]]
        patterns = sorted({", ".join(sample["compile_targets"]) or "none" for sample in row["samples"]})
        lines.append(f"| {row['language']} | {row['mode']} | {row['scenario']} | {statistics.mean(times):.3f} | {statistics.median(times):.3f} | {statistics.stdev(times) if len(times) > 1 else 0:.3f} | {'; '.join(patterns)} |")
    return "\n".join(lines) + "\n"


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--sources", type=positive, default=20)
    parser.add_argument("--fanout", type=positive, default=3)
    parser.add_argument("--rounds", type=positive, default=3)
    parser.add_argument("--warmups", type=positive, default=1)
    parser.add_argument("--languages", nargs="+", choices=["java", "kotlin"], default=["java", "kotlin"])
    parser.add_argument("--modes", nargs="+", choices=MODES, default=list(MODES))
    parser.add_argument("--scenarios", nargs="+", choices=SCENARIOS, default=list(SCENARIOS))
    parser.add_argument("--output", type=Path, default=REPO / "benchmarks/results/incremental")
    parser.add_argument("--distdir", action="append", default=[])
    args = parser.parse_args()
    if args.sources < 3:
        parser.error("--sources must be at least 3 for multi-file edits")
    output = args.output.resolve()
    output.mkdir(parents=True, exist_ok=True)
    bazel = os.environ.get("BAZELISK") or shutil.which("bazelisk") or shutil.which("bazel")
    if not bazel:
        parser.error("Bazelisk/Bazel is required")
    report = {"commit": subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=REPO, text=True).strip(),
              "host": platform.platform(), "cpus": os.cpu_count(), "jobs": 4,
              "bazel_version": (REPO / ".bazelversion").read_text().strip(),
              "elide_version": re.search(r'^DEFAULT_VERSION = "([^"]+)"', (REPO / "elide/private/versions.bzl").read_text(), re.M).group(1),
              "jvm_rule_versions": dict(re.findall(r'bazel_dep\(name = "(rules_java|rules_kotlin)", version = "([^"]+)"', (REPO / "benchmarks/MODULE.bazel").read_text())),
              "parameters": vars(args) | {"output": str(output)}, "results": []}
    with tempfile.TemporaryDirectory(prefix="elide-incremental-") as directory:
        work = Path(directory)
        command = [bazel, "--output_base=" + str(work / "cache")]
        module = (REPO / "benchmarks/MODULE.bazel").read_text().replace('path = ".."', 'path = ' + json.dumps(str(REPO)))
        (work / "MODULE.bazel").write_text(module)
        (work / ".bazelversion").write_text((REPO / ".bazelversion").read_text())
        common = ["--disk_cache=", "--remote_cache=", "--remote_executor=", "--jobs=4",
                  "--java_runtime_version=remotejdk_21", "--tool_java_runtime_version=remotejdk_21",
                  "--java_language_version=21", "--repo_env=ANDROID_HOME=",
                  "--cxxopt=-std=c++17", "--host_cxxopt=-std=c++17", "--noshow_progress",
                  *["--distdir=" + path for path in args.distdir]]

        def run(arguments, log):
            with log.open("w") as stream:
                result = subprocess.run(command + arguments, cwd=work, stdout=stream, stderr=subprocess.STDOUT)
            if result.returncode:
                raise RuntimeError(f"Bazel failed; see {log}\n{log.read_text()[-6000:]}")

        try:
            for language in args.languages:
                for mode in args.modes:
                    if language == "java" and mode == "elide_incremental":
                        continue
                    run(["clean"], output / "clean.log")
                    for package in ("core", "spare", "facade", "clients", "app"):
                        shutil.rmtree(work / package, ignore_errors=True)
                    sources = fixture(work, language, mode, args.sources, args.fanout)
                    flags = list(common)
                    if mode in ("elide_abi", "elide_pruned", "elide_incremental"):
                        flags.append(f"--@rules_elide//config/{'javac' if language == 'java' else 'kotlinc'}:abi_compile_avoidance=true")
                    if mode == "elide_pruned":
                        flags += ["--@rules_elide//elide:emit_jdeps=true", "--@rules_elide//elide:prune_unused_inputs=true"]
                    if mode == "elide_incremental":
                        flags += ["--@rules_elide//config/kotlinc:incremental=true"]
                    targets = ["//core", "//spare", "//facade", "//app", *[f"//clients:client{i}" for i in range(args.fanout)]]
                    for scenario in args.scenarios:
                        row = {"language": language, "mode": mode, "scenario": scenario, "samples": []}
                        for index in range(args.warmups + args.rounds):
                            for path, contents in sources.items():
                                path.write_text(contents)
                            run(["build", *targets, *flags], output / "prepare.log")
                            mutate(sources, scenario, language, index + 1)
                            stem = f"{language}-{mode}-{scenario}-{index}"
                            execution = output / (stem + ".json")
                            start = time.perf_counter()
                            run(["build", *targets, *flags, "--execution_log_json_file=" + str(execution)], output / (stem + ".log"))
                            elapsed = time.perf_counter() - start
                            actions = list(json_entries(execution))
                            compiled = sorted({entry["targetLabel"] for entry in actions if entry.get("mnemonic") in COMPILERS})
                            if scenario == "no_op" and compiled:
                                raise AssertionError(f"No-op recompiled targets: {compiled}")
                            if scenario != "no_op" and not compiled:
                                raise AssertionError(f"Edit compiled no targets: {stem}")
                            if index >= args.warmups:
                                row["samples"].append({"seconds": elapsed, "compile_targets": compiled,
                                                       "abi_targets": sorted({e["targetLabel"] for e in actions if e.get("mnemonic") in {"Turbine", "TurbineDirect", "ElideJavacAbi", "ElideKotlincAbi"}}),
                                                       "actions": dict(Counter(entry.get("mnemonic", "unknown") for entry in actions)),
                                                       "execution_log": execution.name})
                        report["results"].append(row)
                        (output / "results.json").write_text(json.dumps(report, indent=2) + "\n")
                        (output / "results.md").write_text(render(report))
                        print(f"{language} {mode} {scenario}: {statistics.mean(s['seconds'] for s in row['samples']):.3f}s; {row['samples'][-1]['compile_targets']}", flush=True)
        finally:
            subprocess.run(command + ["shutdown"], cwd=work, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    print(output / "results.md")


if __name__ == "__main__":
    main()
