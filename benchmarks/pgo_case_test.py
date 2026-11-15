"""Check that a recorded worker case replays with the inputs each request saw."""
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import textwrap
import unittest

from pgo import capture, record_proxy, replay
from pgo.gen_workrequest import _field, encode, fields, frame, read_frame

# Stands in for `elide javac --persistent_worker`: answers each request with the
# contents of its first argument, or fails if asked to.
WORKER = textwrap.dedent('''\
    #!%s -I
    import sys
    sys.path.insert(0, %r)
    from gen_workrequest import _field, fields, frame, read_frame
    assert "--persistent_worker" in sys.argv, sys.argv
    while (body := read_frame(sys.stdin.buffer)) is not None:
        args = [v.decode() for n, v in fields(body) if n == 1]
        if args[0] == "fail":
            reply = b"\\x08\\x01" + _field(2, b"boom")
        else:
            open(args[1], "w").write(open(args[0]).read())
            reply = _field(2, open(args[0], "rb").read())
        sys.stdout.buffer.write(frame(reply))
        sys.stdout.buffer.flush()
''') % (sys.executable, str(Path(__file__).resolve().parent / "pgo"))

DEEP = "bazel-out/deep/t.out"


def request(arguments, inputs):
    body = b"".join(_field(1, a.encode()) for a in arguments)
    return body + b"".join(_field(2, _field(1, p.encode()) + _field(2, d)) for p, d in inputs)


class CaseTest(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory()
        self.addCleanup(self.directory.cleanup)
        self.work = Path(self.directory.name)
        self.dist = self.work / "dist"
        (self.dist / "bin").mkdir(parents=True)
        (self.dist / "lib").mkdir()
        (self.dist / "lib/tool.jar").write_text("tool")
        (self.dist / "bin/elide").write_text(WORKER)
        (self.dist / "bin/elide").chmod(0o755)

    def record(self, requests):
        """Send (request, files to write first) pairs through the recording proxy."""
        capture.wrap(self.dist, self.work / "wrapped", self.work / "record")
        root = self.work / "execroot"
        (root / "bazel-out/bin").mkdir(parents=True)
        (root / "bazel-out/deep").mkdir()
        (root / "external").mkdir()
        (root / "external/elide").symlink_to(self.work / "wrapped")
        process = subprocess.Popen([str(self.work / "wrapped/bin/elide"), "javac", "--persistent_worker"],
                                   cwd=root, stdin=subprocess.PIPE, stdout=subprocess.PIPE)
        replies = []
        for body, files in requests:
            for name, text in files.items():
                (root / name).write_text(text)
            process.stdin.write(frame(body))
            process.stdin.flush()
            replies.append(dict(fields(read_frame(process.stdout))).get(2))
        process.stdin.close()
        self.assertEqual(process.wait(), 0)
        process.stdout.close()
        return root, replies

    def package(self, root):
        case = self.work / "case"
        streams, absolute, missing = capture.package(
            self.work / "record", case, {str(self.work / "wrapped"): replay.DIST, str(self.dist): replay.DIST})
        (case / "manifest.json").write_text(json.dumps({"streams": streams}))
        return case, streams, absolute, missing

    def test_replay_restores_the_inputs_each_request_saw(self):
        tool = ("external/elide/lib/tool.jar", b"t")
        root, replies = self.record([
            (request(["A.java", "bazel-out/bin/a.out"], [("A.java", b"1"), tool]), {"A.java": "first"}),
            (request(["A.java", "bazel-out/bin/a.out"], [("A.java", b"2"), tool]), {"A.java": "second"}),
            (request(["external/elide/lib/tool.jar", DEEP], [tool]), {}),
        ])
        self.assertEqual(replies, [b"first", b"second", b"tool"])
        case, streams, absolute, missing = self.package(root)
        self.assertEqual((absolute, missing), ([], []))
        self.assertEqual([(s["name"], s["requests"]) for s in streams], [("javac", 3)])
        # Distribution files are neither stored nor listed as inputs, and are relocated in arguments.
        self.assertEqual(sorted(p.name for p in (case / "cas").iterdir()), ["31", "32"])
        with (case / "streams/javac.bin").open("rb") as stream:
            bodies = [read_frame(stream) for _ in range(3)]
        self.assertEqual([v for n, v in fields(bodies[2])], [b"@@ELIDE_DIST@@/lib/tool.jar", DEEP.encode()])
        fresh = self.work / "fresh"
        fresh.mkdir()
        seen = []
        stage = replay.Stage(case / "cas", fresh)
        for body in bodies[:2] * 2:
            replay.prepare(body, stage, {})
            seen.append((fresh / "A.java").read_text())
            (fresh / "A.java").write_text("clobbered by a compile")
        self.assertEqual(seen, ["first", "second", "first", "second"])
        with (self.work / "log").open("wb") as log:
            seconds = replay.replay(self.dist / "bin/elide", case, streams[0], fresh, 2, log)
        self.assertEqual(len(seconds), 2)
        self.assertEqual((fresh / DEEP).read_text(), "tool")

    def test_failed_compile_fails_the_replay(self):
        root, _ = self.record([(request(["fail"], []), {})])
        case, streams, _, _ = self.package(root)
        with (self.work / "log").open("wb") as log, self.assertRaisesRegex(RuntimeError, "boom"):
            replay.replay(self.dist / "bin/elide", case, streams[0], self.work, 1, log)

    def test_machine_specific_arguments_and_uncaptured_inputs_are_reported(self):
        root, _ = self.record([(request(["A.java", "bazel-out/bin/a.out", "--flag=/somewhere/else"],
                                        [("A.java", b"1"), ("gone.jar", b"9")]), {"A.java": "x"})])
        _, _, absolute, missing = self.package(root)
        self.assertEqual((absolute, missing), (["/somewhere/else"], ["gone.jar"]))

    def test_execroot_paths_are_relocated(self):
        capture.wrap(self.dist, self.work / "wrapped", self.work / "record")
        root = self.work / "execroot"
        root.mkdir()
        (root / "A.java").write_text("x")
        subprocess.run([str(self.work / "wrapped/bin/elide"), "javac", "--persistent_worker"], cwd=root, check=True,
                       input=frame(request(["A.java", str(root / "a.out")], [("A.java", b"1")])), stdout=subprocess.DEVNULL)
        case, streams, absolute, _ = self.package(root)
        self.assertEqual(absolute, [])
        fresh = self.work / "fresh"
        fresh.mkdir()
        with (self.work / "log").open("wb") as log:
            replay.replay(self.dist / "bin/elide", case, streams[0], fresh, 1, log)
        self.assertEqual((fresh / "a.out").read_text(), "x")


if __name__ == "__main__":
    unittest.main()
