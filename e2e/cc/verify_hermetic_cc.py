"""Verify the elide_cc_binary output runs and was built without a host C toolchain."""
import json
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile

bazel = sys.argv[1:] or ["bazel"]

# The build actions must invoke the distribution's clang with an empty environment.
aquery = json.loads(subprocess.check_output(
    bazel + ["aquery", "--output=jsonproto", "mnemonic('ElideCc(Compile|Link)', //:hello)"],
    text=True, stderr=subprocess.DEVNULL,
))
actions = aquery.get("actions", [])
assert sorted(a["mnemonic"] for a in actions) == ["ElideCcCompile", "ElideCcCompile", "ElideCcLink"], actions
for action in actions:
    argv = action["arguments"]
    assert "/lib/llvm/toolchain/bin/" in argv[0] and argv[0].endswith("-unknown-linux-gnu-clang"), argv[0]
    assert "-no-canonical-prefixes" in argv, argv
    assert not action.get("environmentVariables"), action.get("environmentVariables")

binary = Path("bazel-bin/hello").absolute()
# Linked by the bundled lld from bundled-clang objects. (The sysroot's own crt
# objects carry a GCC .comment of the distribution's build host; that is expected.)
if shutil.which("readelf"):
    comment = subprocess.run(["readelf", "-p", ".comment", str(binary)],
                             capture_output=True, text=True, check=True).stdout
    assert "Linker: LLD" in comment and "clang version" in comment, comment

with tempfile.TemporaryDirectory(prefix="elide-no-cc-") as empty:
    environment = {"PATH": empty}
    result = subprocess.run([str(binary), "x"], env=environment, capture_output=True, text=True)
    assert result.returncode == 0, result
    assert result.stdout == "hello from elide cc: sqrt(1764)=42 args=1\n", result.stdout
    failed = subprocess.run([str(binary), "fail"], env=environment, capture_output=True, text=True)
    assert failed.returncode == 3, failed
print("elide_cc_binary built with bundled clang/lld and runs without host compilers on PATH.")
