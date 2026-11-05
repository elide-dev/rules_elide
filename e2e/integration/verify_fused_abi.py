"""Verify fused Java/Kotlin headers, cached edit propagation, and runtime results."""
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
    try:
        for language in ("kotlin", "java"):
            kotlin = language == "kotlin"
            compiler = "ElideKotlinc" if kotlin else "ElideJavac"
            config = "kotlinc" if kotlin else "javac"
            (work / "BUILD.bazel").write_text('''load("@rules_elide//elide:defs.bzl", "elide_%s_library", "elide_%s_binary")
elide_%s_library(name = "core", srcs = ["Core.%s"], %s)
elide_%s_binary(name = "app", srcs = ["Main.%s"], deps = [":core"], main_class = "%s")
''' % (language, language, language, "kt" if kotlin else "java",
       "" if kotlin else 'resources = ["resource.txt"]', language,
       "kt" if kotlin else "java", "MainKt" if kotlin else "Main"))
            if kotlin:
                (work / "Main.kt").write_text("fun main() { System.out.println(Core.value() + Core.MAGIC + Core.inlineValue()) }\n")
            else:
                (work / "Main.java").write_text('public class Main { public static void main(String[] args) throws Exception { System.out.println((Core.value() + Core.MAGIC + Core.other()) + ":" + Core.class.getResourceAsStream("/resource.txt").read()); } }\n')
            # This consumer has no runtime reference to Core after inlining.
            # Pruning must still retain its compile-time dependency on Core.
            with (work / "BUILD.bazel").open("a") as build:
                build.write('elide_%s_binary(name = "inlined", srcs = ["Inlined.%s"], deps = [":core"], main_class = "%s")\n' % (language, "kt" if kotlin else "java", "InlinedKt" if kotlin else "Inlined"))
            if kotlin:
                (work / "Inlined.kt").write_text("fun main() { System.out.println(Core.MAGIC + Core.inlineValue()) }\n")
            else:
                (work / "Inlined.java").write_text("public class Inlined { public static void main(String[] args) { System.out.println(Core.MAGIC); } }\n")
            main_path = work / ("Main.kt" if kotlin else "Main.java")
            main_template = main_path.read_text()
            build_template = (work / "BUILD.bazel").read_text()
            configurations = [(workers, pruning, "false", "inherit") for workers, pruning in
                              [("true", "false"), ("false", "false"), ("true", "true"), ("false", "true")]]
            if not kotlin:
                configurations += [("true", "false", "true", "inherit"), ("true", "true", "true", "inherit")]
            configurations.append(("true", "false", "false", "combined"))
            for workers, pruning, classpath_cache, abi_mode in configurations:
                (work / "BUILD.bazel").write_text(build_template.replace("name = ", 'abi_mode = "combined", name = ') if abi_mode == "combined" else build_template)
                global_abi = "false" if abi_mode == "combined" else "true"
                previous = None
                resource = "A"
                consumer_offset = 0
                main_path.write_text(main_template)
                cases = [("initial", 1, 2, 3, "", True),
                         ("body", 10, 2, 3, "", False),
                         ("constant", 10, 20, 3, "", True),
                         ("inline" if kotlin else "second_body", 10, 20, 30, "", kotlin),
                         ("signature", 10, 20, 30, "fun added(): Int = 0" if kotlin else "public static int added() { return 0; }", True)]
                cases.append(("no_op", *cases[-1][1:-1], False))
                if not kotlin:
                    cases.append(("consumer_body", *cases[-1][1:-1], False))
                    cases.append(("resource", *cases[-1][1:-1], False))
                for name, body, constant, inline, extra, changed in cases:
                    if kotlin:
                        (work / "Core.kt").write_text(f"object Core {{ fun value(): Int = {body}; const val MAGIC = {constant}; inline fun inlineValue(): Int = {inline}; {extra} }}\n")
                    else:
                        (work / "Core.java").write_text(f"public class Core {{ public static int value() {{ return {body}; }} public static final int MAGIC = {constant}; public static int other() {{ return {inline}; }} {extra} }}\n")
                        if name == "resource":
                            resource = "B"
                        (work / "resource.txt").write_text(resource)
                    if name == "consumer_body":
                        consumer_offset = 7
                        main_path.write_text(main_template.replace("System.out.println(", "System.out.println(7 + "))
                    log = work / f"{language}-{workers}-{pruning}-{classpath_cache}-{abi_mode}-{name}.json"
                    subprocess.run(bazel + ["build", "//:core", "//:app", "//:inlined", *sys.argv[1:],
                        f"--@rules_elide//config/{config}:abi_compile_avoidance={global_abi}",
                        f"--@rules_elide//config/{config}:abi_from_compile={global_abi}",
                        "--@rules_elide//elide:use_workers=" + workers,
                        "--@rules_elide//config/javac:classpath_cache=" + classpath_cache,
                        "--@rules_elide//elide:prune_unused_inputs=" + pruning,
                        "--java_runtime_version=remotejdk_21", "--tool_java_runtime_version=remotejdk_21",
                        "--disk_cache=", "--remote_cache=", "--remote_executor=",
                        "--execution_log_json_file=" + str(log)], cwd=work, check=True)
                    actions = list(entries(log))
                    assert not any(a.get("mnemonic") == compiler + "Abi" for a in actions), actions
                    rebuilt = {a.get("targetLabel") for a in actions if a.get("mnemonic") == compiler}
                    digest = hashlib.sha256((work / "bazel-bin/core_abi.jar").read_bytes()).digest()
                    context = (language, workers, pruning, classpath_cache, abi_mode, name)
                    if previous is not None:
                        assert (digest != previous) == changed, (context, "header")
                        assert ("//:app" in rebuilt) == (changed or name == "consumer_body"), (context, rebuilt)
                        assert ("//:inlined" in rebuilt) == changed, (context, rebuilt)
                    if name in ("no_op", "resource"):
                        assert not rebuilt, (context, rebuilt)
                    previous = digest
                    result = subprocess.check_output([str(work / "bazel-bin/app_launcher.sh")], cwd=work, text=True).strip()
                    expected = str(body + constant + inline + consumer_offset) + ("" if kotlin else ":" + str(ord(resource)))
                    assert result == expected, (context, result, expected)
                    result = subprocess.check_output([str(work / "bazel-bin/inlined_launcher.sh")], cwd=work, text=True).strip()
                    expected = str(constant + (inline if kotlin else 0))
                    assert result == expected, (context, "inlined", result, expected)
    finally:
        subprocess.run(bazel + ["shutdown"], cwd=work, check=False)
print("Java/Kotlin fused ABI headers, edit propagation, and runtime outputs pass in both worker modes with pruning on/off; Per-target combined mode overrides disabled global flags; Java classpath caching invalidates changed dependency jars and resource edits preserve compile caches.")
