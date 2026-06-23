#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0
"""Emit one length-delimited Bazel `WorkRequest` (proto) to stdout.

The arguments passed on argv become the `WorkRequest.arguments` (field 1,
repeated string) — i.e. the kotlinc argv a resident `elide kotlinc
--persistent_worker` parses for one compile (the same shape rules_elide's
ElideWorker forwards: leading `--` kept, no `elide kotlinc` prefix). No `inputs`
are set (digest IC is optional for profiling).

Concatenate several invocations to build a multi-request stream for the warm
worker loop:  `{ gen ...; gen ...; } | elide --safe-close kotlinc --persistent_worker`.

Hand-encoded so the harness needs no protobuf dependency; only string fields are
used, which is trivial to encode correctly.
"""
import sys


def _varint(n: int) -> bytes:
    out = bytearray()
    while True:
        b = n & 0x7F
        n >>= 7
        out.append(b | 0x80 if n else b)
        if not n:
            return bytes(out)


def main() -> None:
    # field 1, wire type 2 (length-delimited): tag byte 0x0A per repeated string.
    msg = b"".join(
        b"\x0a" + _varint(len(a.encode())) + a.encode() for a in sys.argv[1:]
    )
    # The stream is a sequence of length-delimited messages (writeDelimitedTo).
    sys.stdout.buffer.write(_varint(len(msg)) + msg)


if __name__ == "__main__":
    main()
