"""Check actual cache invalidation in an isolated Java dependency graph.

Pass Bazel build options as arguments, e.g. --distdir=/path/to/archives.
The working checkout is never modified. Shared caches and remote execution are
disabled: this experiment measures local action-cache invalidation after edits.
"""
import json
from pathlib import Path
import subprocess
import sys
import tempfile

repo = Path(__file__).resolve().parents[2]


def entries(path):
    text = path.read_text()
    decoder = json.JSONDecoder()
    while text.strip():
        value, end = decoder.raw_decode(text.lstrip())
        yield value
        text = text.lstrip()[end:]


with tempfile.TemporaryDirectory(prefix="elide-pruning-") as directory:
    work = Path(directory)
    bazel = ["bazel", "--output_base=" + str(work / "cache")]
    (work / ".bazelversion").write_text((repo / ".bazelversion").read_text())
    (work / "MODULE.bazel").write_text('''module(name = "pruning_probe")
bazel_dep(name = "rules_elide", version = "0.0.0")
local_path_override(module_name = "rules_elide", path = %s)
elide = use_extension("@rules_elide//elide:extensions.bzl", "elide")
elide.install(version = "1.6.2")
use_repo(elide, "elide_toolchains")
register_toolchains("@elide_toolchains//:all")
''' % json.dumps(str(repo)))
    (work / "BUILD.bazel").write_text('''load("@rules_elide//elide:defs.bzl", "elide_java_library")
elide_java_library(name = "used", srcs = ["Used.java"])
elide_java_library(name = "spare", srcs = ["Spare.java"])
elide_java_library(name = "consumer", srcs = ["Consumer.java"], deps = [":used", ":spare"])
''')
    (work / "Used.java").write_text("package needed; public class Used { public static int value() { return 1; } }")
    (work / "Spare.java").write_text("package spare; public class Spare {}")
    (work / "Consumer.java").write_text("import needed.Used; public class Consumer { public int value() { return Used.value(); } }")

    def build(label):
        log = work / (label + ".json")
        subprocess.run(bazel + [
            "build", "//:consumer",
            "--@rules_elide//elide:use_workers=false",
            "--@rules_elide//elide:prune_unused_inputs=true",
            "--java_runtime_version=remotejdk_21",
            "--tool_java_runtime_version=remotejdk_21",
            "--execution_log_json_file=" + str(log),
            *sys.argv[1:],
            "--disk_cache=",
            "--remote_cache=",
            "--remote_executor=",
        ], cwd=work, check=True)
        return {entry.get("targetLabel") for entry in entries(log)
                if entry.get("mnemonic") == "ElideJavac"}

    try:
        assert "//:consumer" in build("initial"), "Initial compile was not recorded"
        assert "spare-ijar.jar" in (work / "bazel-bin/consumer_classes.jar.unused").read_text()
        (work / "Spare.java").write_text("package spare; public class Spare { public int added() { return 2; } }")
        rebuilt = build("unused_changed")
        assert "//:spare" in rebuilt, rebuilt
        assert "//:consumer" not in rebuilt, rebuilt
        (work / "Used.java").write_text("package needed; public class Used { public static int value() { return 1; } public int added() { return 2; } }")
        rebuilt = build("used_changed")
        assert "//:used" in rebuilt and "//:consumer" in rebuilt, rebuilt
    finally:
        subprocess.run(bazel + ["shutdown"], cwd=work, check=False)
print("Unused dependency edits are pruned; used dependency ABI edits rebuild the consumer.")
