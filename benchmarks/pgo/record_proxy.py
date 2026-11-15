# SPDX-License-Identifier: Apache-2.0
"""Stand in for `bin/elide` and record what a real build asks its workers to do.

`capture.py` installs a launcher that calls `main(real, record)`. One-shot
invocations exec the real binary untouched. Persistent workers are proxied: each
WorkRequest is appended to `<record>/<start>-<pid>.bin`, and every input it
names is copied into `<record>/cas/<digest>` before the request is forwarded,
so a replay can restore exactly the files that request saw. Inputs that belong
to the Elide distribution are not copied: a replay brings its own. The execroot
prefix they were seen under is noted in `<start>-<pid>.json` instead.
"""
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import time

from gen_workrequest import fields, frame, read_frame


def inputs(body):
    """Yield (path, digest hex) for each input of an encoded WorkRequest."""
    for number, value in fields(body):
        if number == 2:
            entry = dict(fields(value))
            yield entry.get(1, b"").decode(), entry.get(2, b"").hex()


def store(cas, path, key):
    """Copy `path` into the store under `key`; concurrent workers may race."""
    target = cas / key
    if not key or target.exists() or not os.path.isfile(path):
        return
    scratch = cas / f".{key}.{os.getpid()}"
    shutil.copyfile(path, scratch)
    os.replace(scratch, target)


def tool_prefix(path, dist):
    """Return the execroot prefix that maps to `dist` if `path` lies inside it."""
    resolved = os.path.realpath(path)
    if not resolved.startswith(dist + os.sep):
        return None
    relative = resolved[len(dist):]
    return path[:-len(relative)] if path.endswith(relative) else path


def main(real, record):
    argv = sys.argv[1:]
    if "--persistent_worker" not in argv:
        os.execv(real, [real, *argv])
    record = Path(record)
    cas = record / "cas"
    cas.mkdir(parents=True, exist_ok=True)
    stem = record / f"{time.time_ns()}-{os.getpid()}"
    dist, prefixes, tools = os.path.realpath(Path(real).parents[1]), {}, set()

    def describe():
        stem.with_suffix(".json").write_text(json.dumps(
            {"argv": argv, "cwd": os.getcwd(), "tools": sorted(tools)}))

    describe()
    child = subprocess.Popen([real, *argv], stdin=subprocess.PIPE)
    with stem.with_suffix(".bin").open("wb") as stream:
        while (body := read_frame(sys.stdin.buffer)) is not None:
            for path, key in inputs(body):
                if path not in prefixes:
                    prefixes[path] = tool_prefix(path, dist)
                if prefixes[path] is None:
                    store(cas, path, key)
                elif prefixes[path] not in tools:
                    tools.add(prefixes[path])
                    describe()
            data = frame(body)
            stream.write(data)
            stream.flush()
            child.stdin.write(data)
            child.stdin.flush()
    child.stdin.close()
    sys.exit(child.wait())
