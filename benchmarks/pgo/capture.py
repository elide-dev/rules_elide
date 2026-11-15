#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0
"""Capture a replayable worker case from a real rules_elide build.

Runs the incremental benchmark matrix (clean build plus every edit scenario)
against a production workload, with `bin/elide` replaced by a recording proxy,
then packages what the Elide workers were asked to do:

    <output>/manifest.json      streams, provenance, anything not relocatable
    <output>/streams/<tool>.bin WorkRequests, in the order they were sent
    <output>/cas/<digest>       every input file those requests read, except the
                                Elide distribution's own, which replay supplies
    <output>/replay.py          Bazel-free replay (plus gen_workrequest.py)

    capture.py --elide-dist DIST --output cases/java --commons-lang CHECKOUT
    capture.py --elide-dist DIST --output cases/kotlin --kotlin-builder

DIST is an extracted Elide distribution (the directory holding bin/elide). Use
a release binary: the case records requests, not profiles. Train with
`replay.py --elide <instrumented>/bin/elide --profiles <dir>`.
"""
import argparse
import json
from pathlib import Path
import re
import shutil
import subprocess
import sys
import tarfile
import tempfile

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
from gen_workrequest import encode, fields, frame, read_frame  # noqa: E402
from record_proxy import inputs  # noqa: E402
from replay import DIST, ROOT  # noqa: E402

ABSOLUTE = re.compile(r"(?:^|[=:,])(/[^=:,]+)")


def wrap(dist, wrapped, record):
    """Mirror `dist` with symlinks, except `bin/elide`, which records."""
    (wrapped / "bin").mkdir(parents=True)
    for child in dist.iterdir():
        if child.name != "bin":
            (wrapped / child.name).symlink_to(child)
    for child in (dist / "bin").iterdir():
        if child.name != "elide":
            (wrapped / "bin" / child.name).symlink_to(child)
    launcher = wrapped / "bin/elide"
    launcher.write_text(f"#!{sys.executable} -I\nimport sys\nsys.path.insert(0, {str(HERE)!r})\n"
                        f"import record_proxy\nrecord_proxy.main({str(dist / 'bin/elide')!r}, {str(record)!r})\n")
    launcher.chmod(0o755)


def tool(argv):
    return next(a for a in argv if not a.startswith("-"))


def package(record, output, substitutions):
    """Merge per-process recordings into one relocatable stream per tool."""
    streams, absolute, missing = {}, set(), set()
    (output / "streams").mkdir(parents=True)
    (output / "cas").mkdir()
    for meta in sorted(record.glob("*.json")):
        info = json.loads(meta.read_text())
        tools = tuple(prefix + "/" for prefix in info["tools"])
        # Longest first, so a relocated path is never rewritten twice.
        replacements = dict(sorted((substitutions | {info["cwd"]: ROOT} | dict.fromkeys(info["tools"], DIST)).items(),
                                   key=lambda item: -len(item[0])))
        stream = streams.setdefault(tool(info["argv"]), {"argv": info["argv"], "bodies": []})
        if stream["argv"] != info["argv"]:
            raise ValueError(f"{tool(info['argv'])} workers started with differing arguments")
        with meta.with_suffix(".bin").open("rb") as source:
            while (body := read_frame(source)) is not None:
                decoded = []
                for number, value in fields(body):
                    if number == 1:
                        text = value.decode()
                        for old, new in replacements.items():
                            text = text.replace(old, new)
                        absolute.update(ABSOLUTE.findall(text))
                        value = text.encode()
                    elif number == 2 and dict(fields(value)).get(1, b"").decode().startswith(tools):
                        continue  # part of the Elide distribution; a replay supplies its own
                    decoded.append((number, value))
                for path, key in inputs(encode(decoded)):
                    if key and (record / "cas" / key).is_file():
                        if not (output / "cas" / key).exists():
                            shutil.copyfile(record / "cas" / key, output / "cas" / key)
                    else:
                        missing.add(path)
                stream["bodies"].append(encode(decoded))
    manifest = []
    for name, stream in sorted(streams.items()):
        file = f"streams/{name}.bin"
        (output / file).write_bytes(b"".join(map(frame, stream["bodies"])))
        manifest.append({"name": name, "argv": stream["argv"], "requests": len(stream["bodies"]), "file": file})
    return manifest, sorted(absolute), sorted(missing)


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--elide-dist", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True, help="Case directory to create; <output>.tar.gz is written beside it")
    workload = parser.add_mutually_exclusive_group(required=True)
    workload.add_argument("--commons-lang", type=Path, help="Commons Lang checkout (Java)")
    workload.add_argument("--kotlin-builder", action="store_true", help="This checkout's KotlinBuilder module (Kotlin)")
    parser.add_argument("--modes", nargs="+", default=["elide_default"], help="Benchmark matrix modes to record")
    parser.add_argument("--rounds", type=int, default=1, help="Recorded builds per edit scenario, after one warm-up that is also recorded")
    args = parser.parse_args()
    dist, output = args.elide_dist.resolve(), args.output.resolve()
    if not (dist / "bin/elide").is_file():
        parser.error(f"{dist} is not an extracted Elide distribution (no bin/elide)")
    if output.exists():
        parser.error(f"{output} already exists")
    version = subprocess.check_output([str(dist / "bin/elide"), "--version"], text=True).strip()
    with tempfile.TemporaryDirectory(prefix="elide-capture-") as directory:
        work = Path(directory)
        wrap(dist, work / "dist", work / "record")
        matrix = [sys.executable, str(HERE.parent / "incremental_matrix.py"), "--elide-local-path", str(work / "dist"),
                  "--modes", *args.modes, "--rounds", str(args.rounds), "--warmups", "1", "--output", str(work / "results")]
        matrix += (["--commons-lang", str(args.commons_lang), "--languages", "java"] if args.commons_lang
                   else ["--kotlin-builder", "--languages", "kotlin"])
        subprocess.run(matrix, check=True)
        streams, absolute, missing = package(work / "record", output, {str(work / "dist"): DIST, str(dist): DIST})
        report = json.loads((work / "results/results.json").read_text())
    if not streams:
        shutil.rmtree(output)
        raise SystemExit("no Elide worker requests were recorded")
    for name in ("replay.py", "gen_workrequest.py"):
        shutil.copyfile(HERE / name, output / name)
    (output / "manifest.json").write_text(json.dumps({
        "format": 1, "streams": streams, "elide_version": version,
        "rules_elide_commit": report["commit"], "rules_elide_dirty": report["tracked_changes"],
        "modes": args.modes, "scenarios": report["parameters"]["scenarios"],
        "workload": report.get("source_workload"),
        # Arguments that still name this machine, and inputs that were not captured.
        "absolute_paths": absolute, "missing_inputs": missing,
    }, indent=2) + "\n")
    with tarfile.open(str(output) + ".tar.gz", "w:gz") as archive:
        archive.add(output, arcname=output.name)
    for stream in streams:
        print(f"{stream['name']}: {stream['requests']} requests")
    print(f"case: {output} ({sum(1 for _ in (output / 'cas').iterdir())} input files)")
    if absolute or missing:
        raise SystemExit(f"case is not self-contained: {len(absolute)} absolute path(s), "
                         f"{len(missing)} uncaptured input(s); see manifest.json")


if __name__ == "__main__":
    main()
