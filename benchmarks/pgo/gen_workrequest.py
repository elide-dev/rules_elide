#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0
"""Emit a length-delimited Bazel WorkRequest without a protobuf dependency.

By default argv becomes compiler arguments and inputs are omitted. Use
`--inputs-json paths.json -- <compiler args>` to attach SHA-256 input digests.
The JSON file contains a list of file paths, spelled as in the compiler argv.
Digest-keyed caches cannot be exercised by requests without input digests.
"""
import hashlib
import json
from pathlib import Path
import sys


def _varint(n: int) -> bytes:
    out = bytearray()
    while True:
        b = n & 0x7F
        n >>= 7
        out.append(b | 0x80 if n else b)
        if not n:
            return bytes(out)


def _field(number: int, data: bytes) -> bytes:
    return _varint(number * 8 + 2) + _varint(len(data)) + data


def request(arguments, inputs=()):
    msg = b"".join(_field(1, a.encode()) for a in arguments)
    for path in inputs:
        entry = _field(1, str(path).encode())
        entry += _field(2, hashlib.sha256(Path(path).read_bytes()).digest())
        msg += _field(2, entry)
    return _varint(len(msg)) + msg


def _read_varint(data, offset):
    value = 0
    for shift in range(0, 70, 7):
        if offset >= len(data):
            raise ValueError("truncated protobuf varint")
        b = data[offset]
        offset += 1
        value |= (b & 127) << shift
        if b < 128:
            return value, offset
    raise ValueError("oversized protobuf varint")


def fields(data):
    offset = 0
    while offset < len(data):
        tag, offset = _read_varint(data, offset)
        value, offset = _read_varint(data, offset)
        if tag & 7 == 2:
            end = offset + value
            if end > len(data):
                raise ValueError("truncated protobuf field")
            value, offset = data[offset:end], end
        elif tag & 7 != 0:
            raise ValueError("unsupported protobuf wire type")
        yield tag >> 3, value


def check_responses(data, expected):
    """Fail on compiler errors, cancellation, truncated streams, or lost replies."""
    offset, count = 0, 0
    while offset < len(data):
        size, offset = _read_varint(data, offset)
        end = offset + size
        if end > len(data):
            raise ValueError("truncated WorkResponse")
        response = dict(fields(data[offset:end]))
        if response.get(1, 0) or response.get(4, 0):
            raise ValueError("worker compile failed: " + response.get(2, b"").decode(errors="replace"))
        count += 1
        offset = end
    if count != expected:
        raise ValueError(f"expected {expected} responses, received {count}")


def main() -> None:
    args, inputs = sys.argv[1:], []
    if args[:1] == ["--inputs-json"]:
        if len(args) < 3 or args[2] != "--":
            raise SystemExit("usage: --inputs-json paths.json -- <compiler args>")
        inputs = json.loads(Path(args[1]).read_text())
        args = args[3:]
    sys.stdout.buffer.write(request(args, inputs))


if __name__ == "__main__":
    main()
