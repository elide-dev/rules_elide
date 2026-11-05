"""Verify fused Kotlin headers, cached edit propagation, and runtime results."""
import hashlib
import json
from pathlib import Path
import subprocess
import sys
import tempfile

repo = Path(__file__).resolve().parents[2]


def entries(path):
    decoder = json.JSONDecoder()
    text = path.read_text()
    while text.strip():
        entry, end = decoder.raw_decode(text.lstrip())
        yield entry
        text = text.lstrip()[end:]


with tempfile.TemporaryDirectory(prefix="elide-fused-abi-") as directory:
    work = Path(directory)
    bazel = ["bazel", "--output_base=" + str(work / "cache")]
    (work / ".bazelversion").write_text((repo / ".bazelversion").read_text())
    (work / "MODULE.bazel").write_text('''module(name = "fused_probe")
bazel_dep(name = "rules_elide", version = "0.0.0")
local_path_override(module_name = "rules_elide", path = %s)
elide = use_extension("@rules_elide//elide:extensions.bzl", "elide")
elide.install(version = "1.6.2")
use_repo(elide, "elide_toolchains")
register_toolchains("@elide_toolchains//:all")
''' % json.dumps(str(repo)))
    (work / "BUILD.bazel").write_text('''load("@rules_elide//elide:defs.bzl", "elide_kotlin_library", "elide_kotlin_binary")
elide_kotlin_library(name = "core", srcs = ["Core.kt"])
elide_kotlin_binary(name = "app", srcs = ["Main.kt"], deps = [":core"], main_class = "MainKt")
''')
    (work / "Main.kt").write_text("fun main() { System.out.println(Core.value() + Core.MAGIC + Core.inlineValue()) }\n")
    try:
        for workers in ("true", "false"):
            previous = None
            # Each row follows the previous edit. An additive public API change
            # must invalidate the consumer even when its runtime value is unchanged.
            cases = [("initial", 1, 2, 3, "", True),
                     ("body", 10, 2, 3, "", False),
                     ("constant", 10, 20, 3, "", True),
                     ("inline", 10, 20, 30, "", True),
                     ("signature", 10, 20, 30, "fun added(): Int = 0", True),
                     ("no_op", 10, 20, 30, "fun added(): Int = 0", False)]
            for name, body, constant, inline, extra, changed in cases:
                (work / "Core.kt").write_text(f"object Core {{ fun value(): Int = {body}; const val MAGIC = {constant}; inline fun inlineValue(): Int = {inline}; {extra} }}\n")
                log = work / f"{workers}-{name}.json"
                subprocess.run(bazel + ["build", "//:core", "//:app", *sys.argv[1:],
                    "--@rules_elide//config/kotlinc:abi_compile_avoidance=true",
                    "--@rules_elide//config/kotlinc:abi_from_compile=true",
                    "--@rules_elide//elide:use_workers=" + workers,
                    "--java_runtime_version=remotejdk_21", "--tool_java_runtime_version=remotejdk_21",
                    "--disk_cache=", "--remote_cache=", "--remote_executor=",
                    "--execution_log_json_file=" + str(log)], cwd=work, check=True)
                actions = list(entries(log))
                assert not any(a.get("mnemonic") == "ElideKotlincAbi" for a in actions), actions
                rebuilt = {a.get("targetLabel") for a in actions if a.get("mnemonic") == "ElideKotlinc"}
                digest = hashlib.sha256((work / "bazel-bin/core_abi.jar").read_bytes()).digest()
                if previous is not None:
                    assert (digest != previous) == changed, (workers, name, "header")
                    assert ("//:app" in rebuilt) == changed, (workers, name, rebuilt)
                if name == "no_op":
                    assert not rebuilt, rebuilt
                previous = digest
                result = subprocess.check_output([str(work / "bazel-bin/app_launcher.sh")], cwd=work, text=True).strip()
                assert result == str(body + constant + inline), (workers, name, result)
    finally:
        subprocess.run(bazel + ["shutdown"], cwd=work, check=False)
print("Fused ABI headers preserve body avoidance and propagate constants, inline bodies, and public signatures; runtime outputs match in both worker modes.")
