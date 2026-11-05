#!/usr/bin/env python3
"""Measure edit propagation through a generated core -> facade -> clients -> app graph."""
import argparse
import gzip
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

import commons_lang_fixture
import kotlin_builder_fixture

REPO = Path(__file__).resolve().parents[1]
SCENARIOS = (
    "clean", "no_op", "comment", "body", "private_member", "internal_module_api",
    "public_module_api", "multi_file_body", "multi_module_body",
    "multi_module_api", "unused_dependency_api", "inline_or_constant",
)
MODES = ("vanilla", "vanilla_abi", "elide", "elide_abi", "elide_pruned", "elide_incremental", "elide_fused", "elide_fused_pruned", "elide_hybrid", "elide_selective")
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


def profile_summary(path):
    """Summarize Bazel trace counters; missing samples are unknown, not zero."""
    with gzip.open(path, "rt") as stream:
        events = json.load(stream)["traceEvents"]
    critical = [e for e in events if e.get("cat") == "critical path component" and e.get("ph") == "X"]
    series = {}
    for event in events:
        if event.get("ph") != "C":
            continue
        for key, value in event.get("args", {}).items():
            if isinstance(value, (int, float)) and not isinstance(value, bool):
                series.setdefault((event["name"], key), []).append((event["ts"], value))
    counters = {}
    for (name, key), samples in series.items():
        # Bazel averages resources into one-second buckets, including a final
        # partial bucket. A later positive bucket proves collection crossed the
        # preceding bucket boundary. Never call a partial bucket a memory win.
        positive = [timestamp for timestamp, value in samples if value > 0]
        complete = [value for timestamp, value in samples if positive and timestamp < max(positive)]
        if complete:
            counters.setdefault(name, {})[key] = max(complete)
    return {
        "critical_path_action_seconds": sum(e["dur"] for e in critical) / 1_000_000,
        "critical_path_span_seconds": (max(e["ts"] + e["dur"] for e in critical) - min(e["ts"] for e in critical)) / 1_000_000 if critical else 0,
        "worker_memory_mib_max_sample": counters.get("Total worker memory usage", {}).get("workers memory"),
        "bazel_heap_nonheap_mib_max_sample": counters.get("Memory usage (Bazel)", {}).get("memory"),
        "worker_memory_mib_by_mnemonic_max_sample": counters.get("Per-mnemonic worker memory usage", {}),
    }


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
    if mode not in ("vanilla", "vanilla_abi"):
        rule = f"elide_{'java' if language == 'java' else 'kotlin'}_library"
        load = "@rules_elide//elide:defs.bzl"
    sources = {}

    def target(package, name, classes, deps):
        directory = work / package
        directory.mkdir(exist_ok=True)
        build = directory / "BUILD.bazel"
        prefix = f'load("{load}", "{rule}")\npackage(default_visibility=["//visibility:public"])\n'
        options = ", javac_opts=[\"--release\", \"21\"]" if language == "java" and mode != "vanilla" else ""
        if mode == "elide_hybrid":
            options += ', abi_mode="' + ("separate" if package == "core" else "combined") + '"'
        if mode == "elide_selective":
            options += ', abi_mode="combined", incremental_mode="' + ("on" if package == "core" else "off") + '"'
        stanza = f'{rule}(name={json.dumps(name)}, srcs={json.dumps([c + "." + extension for c in classes])}, deps={json.dumps(deps)}{options})\n'
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
        "clean": [], "no_op": [], "comment": [("Core0", "comment")],
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
    if "source_workload" in report:
        workload = report["source_workload"]
        lines[4:4] = [f"Production sources: {workload['project']} at `{workload['revision']}`; {workload['source_files']} source files.",
                      f"Source SHA-256: `{workload['source_sha256']}`; checkout dirty: `{workload['checkout_dirty']}`.",
                      "The downstream consumer graph is generated. Runtime assertions run outside build timing.", ""]
    for row in report["results"]:
        times = [sample["seconds"] for sample in row["samples"]]
        patterns = sorted({", ".join(sample["compile_targets"]) or "none" for sample in row["samples"]})
        lines.append(f"| {row['language']} | {row['mode']} | {row['scenario']} | {statistics.mean(times):.3f} | {statistics.median(times):.3f} | {statistics.stdev(times) if len(times) > 1 else 0:.3f} | {'; '.join(patterns)} |")
    if any("profile" in sample for row in report["results"] for sample in row["samples"]):
        lines += ["", "## Trace metrics", "",
                  "Memory values are maximum complete bucket averages across measured samples, not process peak RSS.",
                  "Bazel memory is heap plus non-heap; worker memory excludes non-worker actions. Missing counters are n/a.", "",
                  "| Language | Mode | Edit | Mean critical-path span (s) | Worker memory (MiB) | Bazel heap + non-heap (MiB) |",
                  "| --- | --- | --- | ---: | ---: | ---: |"]
        for row in report["results"]:
            profiles = [s["profile"] for s in row["samples"] if "profile" in s]
            if not profiles:
                continue
            cells = []
            for key in ("worker_memory_mib_max_sample", "bazel_heap_nonheap_mib_max_sample"):
                values = [p[key] for p in profiles if p[key] is not None]
                cells.append(f"{max(values):.1f}" if values else "n/a")
            critical = statistics.mean(p["critical_path_span_seconds"] for p in profiles)
            lines.append(f"| {row['language']} | {row['mode']} | {row['scenario']} | {critical:.3f} | {' | '.join(cells)} |")
    return "\n".join(lines) + "\n"


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    workload_args = parser.add_mutually_exclusive_group()
    workload_args.add_argument("--kotlin-builder", action="store_true", help="Benchmark this checkout's production KotlinBuilder module (Kotlin only)")
    workload_args.add_argument("--commons-lang", type=Path, help="Benchmark a local Commons Lang source checkout in an isolated copy (Java only)")
    parser.add_argument("--profiles", action="store_true", help="Retain Bazel traces and summarize critical-path and sampled memory counters")
    parser.add_argument("--sources", type=positive, default=20)
    parser.add_argument("--fanout", type=positive, default=3)
    parser.add_argument("--rounds", type=positive, default=3)
    parser.add_argument("--warmups", type=positive, default=1)
    parser.add_argument("--languages", nargs="+", choices=["java", "kotlin"], default=["java", "kotlin"])
    parser.add_argument("--modes", nargs="+", choices=MODES, default=[mode for mode in MODES if mode not in ("elide_hybrid", "elide_selective")])
    parser.add_argument("--scenarios", nargs="+", choices=SCENARIOS, default=None)
    parser.add_argument("--output", type=Path, default=REPO / "benchmarks/results/incremental")
    parser.add_argument("--distdir", action="append", default=[])
    args = parser.parse_args()
    production = None
    source_metadata = None
    java = None
    workload = None
    if args.commons_lang:
        workload = commons_lang_fixture
        if args.languages != ["java"]:
            parser.error("--commons-lang requires --languages java")
        if args.scenarios and set(args.scenarios) - set(commons_lang_fixture.SCENARIOS):
            parser.error("Commons Lang supports: " + ", ".join(commons_lang_fixture.SCENARIOS))
        java = shutil.which("java")
        if not java:
            parser.error("Commons Lang runtime checks require java (JDK 21+) on PATH")
        production, source_metadata = commons_lang_fixture.snapshot(args.commons_lang)
        args.commons_lang = str(args.commons_lang.resolve())
        args.scenarios = args.scenarios or list(commons_lang_fixture.SCENARIOS)
    elif args.kotlin_builder:
        workload = kotlin_builder_fixture
        if args.languages != ["kotlin"]:
            parser.error("--kotlin-builder requires --languages kotlin")
        if args.scenarios and set(args.scenarios) - set(workload.SCENARIOS):
            parser.error("KotlinBuilder supports: " + ", ".join(workload.SCENARIOS))
        production, source_metadata = workload.snapshot(REPO)
        args.scenarios = args.scenarios or list(workload.SCENARIOS)
    else:
        args.scenarios = args.scenarios or list(SCENARIOS)
    if production is None and args.sources < 3:
        parser.error("--sources must be at least 3 for multi-file edits")
    output = args.output.resolve()
    output.mkdir(parents=True, exist_ok=True)
    bazel = os.environ.get("BAZELISK") or shutil.which("bazelisk") or shutil.which("bazel")
    if not bazel:
        parser.error("Bazelisk/Bazel is required")
    report = {"commit": subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=REPO, text=True).strip(),
              "tracked_changes": bool(subprocess.check_output(["git", "status", "--porcelain", "--untracked-files=no"], cwd=REPO, text=True).strip()),
              "host": platform.platform(), "cpus": os.cpu_count(), "jobs": 4,
              "bazel_version": (REPO / ".bazelversion").read_text().strip(),
              "elide_version": re.search(r'^DEFAULT_VERSION = "([^"]+)"', (REPO / "elide/private/versions.bzl").read_text(), re.M).group(1),
              "jvm_rule_versions": dict(re.findall(r'bazel_dep\(name = "(rules_java|rules_kotlin)", version = "([^"]+)"', (REPO / "benchmarks/MODULE.bazel").read_text())),
              "isolated_mode_servers": True,
              "java_release": 21,
              "parameters": vars(args) | {"output": str(output)}, "results": []}
    if source_metadata:
        report["source_workload"] = source_metadata
        if args.commons_lang:
            report["stock_error_prone_checks"] = False
            report["runtime_java"] = subprocess.check_output([java, "-version"], stderr=subprocess.STDOUT, text=True).strip()
        else:
            report["runtime_java"] = "Bazel remotejdk_21 via stock java_binary launcher"
    with tempfile.TemporaryDirectory(prefix="elide-incremental-") as directory:
        work = Path(directory)
        command = [bazel, "--output_base=" + str(work / "cache")]
        module = (REPO / "benchmarks/MODULE.bazel").read_text().replace('path = ".."', 'path = ' + json.dumps(str(REPO)))
        if args.kotlin_builder:
            module += '\nregister_toolchains("//:stock_kotlin")\n'
            root_module = (REPO / "MODULE.bazel").read_text()
            report["protocol_rule_versions"] = dict(re.findall(r'bazel_dep\(name = "(protobuf|rules_proto)", version = "([^"]+)"', root_module))
            module += "\n" + "\n".join(re.findall(r'^bazel_dep\(name = "(?:rules_proto|protobuf)"[^\n]+', root_module, re.M)) + "\n"
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
                    if language == "java" and mode in ("vanilla_abi", "elide_incremental", "elide_selective"):
                        continue
                    # Each mode gets a fresh server/worker pool. Baseline builds
                    # and warm-ups remain untimed, so measured builds stay warm.
                    run(["shutdown"], output / "shutdown.log")
                    run(["clean"], output / "clean.log")
                    for package in ("core", "spare", "facade", "clients", "app", "protocol"):
                        shutil.rmtree(work / package, ignore_errors=True)
                    sources = fixture(work, language, mode, 3 if production is not None else args.sources, args.fanout)
                    if production is not None:
                        sources = workload.install(work, sources, production, args.fanout)
                    flags = list(common)
                    if args.commons_lang and mode == "vanilla":
                        # Upstream builds with javac, without Bazel's extra Error Prone policy.
                        flags.append("--javacopt=-XepDisableAllChecks")
                    if mode == "vanilla_abi":
                        flags.append("--define=experimental_use_abi_jars=1")
                    if mode in ("elide_abi", "elide_pruned", "elide_incremental", "elide_fused", "elide_fused_pruned"):
                        flags.append(f"--@rules_elide//config/{'javac' if language == 'java' else 'kotlinc'}:abi_compile_avoidance=true")
                    if mode in ("elide_pruned", "elide_fused_pruned", "elide_selective"):
                        flags += ["--@rules_elide//elide:emit_jdeps=true", "--@rules_elide//elide:prune_unused_inputs=true"]
                    if mode in ("elide_fused", "elide_fused_pruned"):
                        flags.append(f"--@rules_elide//config/{'javac' if language == 'java' else 'kotlinc'}:abi_from_compile=true")
                    if mode == "elide_incremental":
                        flags += ["--@rules_elide//config/kotlinc:incremental=true"]
                    targets = ["//core", "//spare", "//facade", "//app", *[f"//clients:client{i}" for i in range(args.fanout)]]
                    build_targets = targets + (["//app:verify"] if args.kotlin_builder else [])
                    for scenario in args.scenarios:
                        row = {"language": language, "mode": mode, "scenario": scenario, "samples": []}
                        for index in range(args.warmups + args.rounds):
                            for path, contents in sources.items():
                                path.write_text(contents)
                            run(["build", *build_targets, *flags], output / "prepare.log")
                            if production is not None:
                                workload.mutate(sources, scenario, index + 1)
                            else:
                                mutate(sources, scenario, language, index + 1)
                            if scenario == "clean":
                                run(["clean"], output / "clean.log")
                            stem = f"{language}-{mode}-{scenario}-{index}"
                            execution = output / (stem + ".json")
                            profile = output / (stem + ".profile.json.gz")
                            profile_flags = ["--profile=" + str(profile), "--generate_json_trace_profile", "--experimental_profile_include_target_label", "--experimental_collect_worker_data_in_profiler"] if args.profiles else []
                            start = time.perf_counter()
                            run(["build", *build_targets, *flags, "--execution_log_json_file=" + str(execution), *profile_flags], output / (stem + ".log"))
                            elapsed = time.perf_counter() - start
                            if production is not None:
                                workload.verify(work, args.fanout, mode, java, output / (stem + ".runtime.log"))
                            actions = list(json_entries(execution))
                            compiled = sorted({entry["targetLabel"] for entry in actions if entry.get("mnemonic") in COMPILERS})
                            if scenario == "clean":
                                expected = {t if ":" in t else t + ":" + t.rsplit("/", 1)[-1] for t in targets}
                                if not expected.issubset(compiled):
                                    raise AssertionError(f"Clean build skipped runtime compilers: {expected - set(compiled)}")
                            if scenario == "no_op" and compiled:
                                raise AssertionError(f"No-op recompiled targets: {compiled}")
                            if scenario != "no_op" and not compiled:
                                raise AssertionError(f"Edit compiled no targets: {stem}")
                            if production is not None and mode not in ("elide", "vanilla") and scenario in ("body", "private_member", "multi_file_body") and compiled != ["//core:core"]:
                                raise AssertionError(f"Implementation edit escaped the library ABI boundary: {compiled}")
                            if args.commons_lang and mode == "vanilla" and scenario in ("body", "private_member", "multi_file_body") and compiled != ["//core:core"]:
                                raise AssertionError(f"Implementation edit escaped the library ABI boundary: {compiled}")
                            if index >= args.warmups:
                                row["samples"].append({"seconds": elapsed, "compile_targets": compiled,
                                                       "abi_targets": sorted({e["targetLabel"] for e in actions if e.get("mnemonic") in {"Turbine", "TurbineDirect", "ElideJavacAbi", "ElideKotlincAbi"}}),
                                                       "actions": dict(Counter(entry.get("mnemonic", "unknown") for entry in actions)),
                                                       "execution_log": execution.name})
                                if args.profiles:
                                    row["samples"][-1].update(profile=profile_summary(profile), profile_file=profile.name)
                        report["results"].append(row)
                        (output / "results.json").write_text(json.dumps(report, indent=2) + "\n")
                        (output / "results.md").write_text(render(report))
                        print(f"{language} {mode} {scenario}: {statistics.mean(s['seconds'] for s in row['samples']):.3f}s; {row['samples'][-1]['compile_targets']}", flush=True)
        finally:
            subprocess.run(command + ["shutdown"], cwd=work, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    print(output / "results.md")


if __name__ == "__main__":
    main()
