"""Guard benchmark input digests and per-request compiler failure detection."""
import hashlib
from pathlib import Path
import tempfile
import unittest

from pgo.gen_workrequest import _field, _read_varint, _varint, check_responses, fields, request


class WorkerProtocolTest(unittest.TestCase):
    def test_digest_tracks_same_path_content_changes(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "dependency.jar"
            path.write_bytes(b"first")
            first = request(["--", str(path)], [path])
            length, start = _read_varint(first, 0)
            self.assertEqual(length, len(first) - start)
            decoded = list(fields(first[start:]))
            self.assertEqual(decoded[:2], [(1, b"--"), (1, str(path).encode())])
            self.assertEqual(dict(fields(decoded[2][1])), {
                1: str(path).encode(), 2: hashlib.sha256(b"first").digest()})
            path.write_bytes(b"other")
            self.assertNotEqual(first, request(["--", str(path)], [path]))

    def test_missing_input_is_not_silently_omitted(self):
        with tempfile.TemporaryDirectory() as directory:
            with self.assertRaises(FileNotFoundError):
                request([], [Path(directory) / "missing.jar"])

    def test_success_with_default_or_explicit_exit_code(self):
        check_responses(b"\x00\x02\x08\x00", 2)

    def test_failure_cancellation_and_missing_replies(self):
        diagnostic = b"\x08\x01" + _field(2, b"compile failed")
        with self.assertRaisesRegex(ValueError, "compile failed"):
            check_responses(_varint(len(diagnostic)) + diagnostic, 1)
        for data in (b"\x02\x20\x01", b"", b"\x00\x00", b"\x80", b"\x03\x08\x00"):
            with self.subTest(data=data), self.assertRaises(ValueError):
                check_responses(data, 1)
