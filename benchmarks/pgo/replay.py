#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0
"""Replay a captured worker case into an Elide binary, without Bazel.

A case (see capture.py) holds the WorkRequest streams a real rules_elide build
sent to `elide <tool> --persistent_worker`, plus every input file those requests
read. Each stream is replayed into one resident process, request by request,
with that request's inputs restored first. Any failed compile fails the replay.

    python3 replay.py --elide /abs/path/to/bin/elide [--loops 3] [--profiles DIR]

With `--profiles`, the binary must be PGO-instrumented: each stream's
`default.iprof` is collected as `<DIR>/<case>-<stream>-worker.iprof`, where
`<case>` is the case directory's name (`java-shim-javac-worker.iprof`).

This file and gen_workrequest.py are copied into every case, so a case replays
with nothing but Python 3 and the Elide binary.
"""
import argparse
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import tempfile
import time

sys.path.insert(0, str(Path(__file__).resolve().parent))
from gen_workrequest import encode, fields, frame, read_frame  # noqa: E402

DIST, ROOT = "@@ELIDE_DIST@@", "@@ROOT@@"
# Bazel creates output directories before an action runs; a replay must too.
OUTPUT = re.compile(r"(?:^|[=:,])(bazel-out/[^=:,]+)")


class Stage:
    """Restores each request's inputs, re-copying any a compile overwrote."""

    def __init__(self, cas, root):
        self.cas, self.root, self.placed = cas, root, {}

    def place(self, path, key):
        target = self.root / path
        try:
            stat = target.stat()
            current = (key, stat.st_ino, stat.st_mtime_ns, stat.st_size)
        except FileNotFoundError:
            current = None
        if current is not None and self.placed.get(path) == current:
            return
        source = self.cas / key
        if not source.is_file():
            raise FileNotFoundError(f"case is missing input {path} ({key})")
        target.parent.mkdir(parents=True, exist_ok=True)
        scratch = target.with_name(target.name + ".replay")
        shutil.copyfile(source, scratch)
        os.replace(scratch, target)
        stat = target.stat()
        self.placed[path] = (key, stat.st_ino, stat.st_mtime_ns, stat.st_size)


def prepare(body, stage, substitutions):
    """Restore a request's inputs and output directories; return it relocated."""
    decoded = []
    for number, value in fields(body):
        if number == 1:
            text = value.decode()
            for token, replacement in substitutions.items():
                text = text.replace(token, replacement)
            for match in OUTPUT.finditer(text):
                (stage.root / match.group(1)).parent.mkdir(parents=True, exist_ok=True)
            value = text.encode()
        elif number == 2:
            entry = dict(fields(value))
            path, key = entry.get(1, b"").decode(), entry.get(2, b"").hex()
            # Inputs no argument names are listed, as in the real request, but not part of the case.
            if key and not os.path.isabs(path) and (stage.cas / key).is_file():
                stage.place(path, key)
        decoded.append((number, value))
    return encode(decoded)


def replay(elide, case, stream, root, loops, log):
    """Run one stream `loops` times in a single process; return seconds per loop."""
    stage = Stage(case / "cas", root)
    substitutions = {DIST: str(elide.resolve().parents[1]), ROOT: str(root)}
    with (case / stream["file"]).open("rb") as source:
        bodies = []
        while (body := read_frame(source)) is not None:
            bodies.append(body)
    argv = stream["argv"] if "--safe-close" in stream["argv"] else ["--safe-close", *stream["argv"]]
    process = subprocess.Popen([str(elide), *argv], cwd=root, stdin=subprocess.PIPE,
                               stdout=subprocess.PIPE, stderr=log)
    seconds = []
    try:
        for _ in range(loops):
            start = time.perf_counter()
            for index, body in enumerate(bodies):
                process.stdin.write(frame(prepare(body, stage, substitutions)))
                process.stdin.flush()
                reply = read_frame(process.stdout)
                if reply is None:
                    raise RuntimeError(f"{stream['name']}: worker exited at request {index}")
                response = dict(fields(reply))
                if response.get(1, 0) or response.get(4, 0):
                    raise RuntimeError(f"{stream['name']}: request {index} failed:\n"
                                       + response.get(2, b"").decode(errors="replace"))
            seconds.append(time.perf_counter() - start)
        process.stdin.close()
        if process.wait() != 0:
            raise RuntimeError(f"{stream['name']}: worker exited with {process.returncode}")
    finally:
        process.kill()
        process.wait()
        process.stdout.close()
        if not process.stdin.closed:
            try:
                process.stdin.close()
            except BrokenPipeError:
                pass
    return seconds


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--elide", type=Path, required=True, help="bin/elide inside an extracted distribution")
    parser.add_argument("--case", type=Path, default=Path(__file__).resolve().parent)
    parser.add_argument("--loops", type=int, default=3, help="Times to replay each stream in one warm process")
    parser.add_argument("--streams", nargs="+", help="Replay only these streams (default: all)")
    parser.add_argument("--profiles", type=Path, help="Collect each stream's default.iprof here; fail if none is written")
    parser.add_argument("--work", type=Path, help="Scratch directory to keep (default: temporary, removed)")
    args = parser.parse_args()
    case = args.case.resolve()
    manifest = json.loads((case / "manifest.json").read_text())
    streams = [s for s in manifest["streams"] if not args.streams or s["name"] in args.streams]
    if not streams:
        parser.error("no matching streams; case has: " + ", ".join(s["name"] for s in manifest["streams"]))
    if args.profiles:
        args.profiles.mkdir(parents=True, exist_ok=True)
    work = args.work.resolve() if args.work else Path(tempfile.mkdtemp(prefix="elide-replay-"))
    try:
        for stream in streams:
            root = work / stream["name"]
            root.mkdir(parents=True, exist_ok=True)
            with (work / (stream["name"] + ".log")).open("wb") as log:
                try:
                    seconds = replay(args.elide, case, stream, root, args.loops, log)
                except Exception:
                    log.flush()
                    sys.stderr.write((work / (stream["name"] + ".log")).read_text(errors="replace")[-4000:])
                    raise
            print(f"{stream['name']}: {stream['requests']} requests x {args.loops}: "
                  + ", ".join(f"{s:.2f}s" for s in seconds), flush=True)
            if args.profiles:
                profile = root / "default.iprof"
                if not profile.is_file() or not profile.stat().st_size:
                    raise SystemExit(f"{stream['name']}: no default.iprof; is {args.elide} PGO-instrumented?")
                shutil.copyfile(profile, args.profiles / f"{case.name}-{stream['name']}-worker.iprof")
    finally:
        if not args.work:
            shutil.rmtree(work, ignore_errors=True)


if __name__ == "__main__":
    main()
