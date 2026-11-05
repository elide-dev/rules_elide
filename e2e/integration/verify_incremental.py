"""Verify native IC publishes complete jars across edits and worker lifecycles."""
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import zipfile

repo = Path(__file__).resolve().parents[2]

with tempfile.TemporaryDirectory(prefix="elide-ic-bazel-") as directory:
    work = Path(directory)
    command = ["bazel", "--output_base=" + str(work / "cache")]
    (work / ".bazelversion").write_text((repo / ".bazelversion").read_text())
    (work / "MODULE.bazel").write_text('''module(name = "ic_probe")
bazel_dep(name = "rules_elide", version = "0.0.0")
local_path_override(module_name = "rules_elide", path = %s)
elide = use_extension("@rules_elide//elide:extensions.bzl", "elide")
elide.install(version = "1.6.2")
use_repo(elide, "elide_toolchains")
register_toolchains("@elide_toolchains//:all")
''' % json.dumps(str(repo)))
    build_file = '''load("@rules_elide//elide:defs.bzl", "elide_kotlin_library", "elide_kotlin_binary")
elide_kotlin_library(name="dep", srcs=["Dep.kt"])
elide_kotlin_library(name="core", srcs=glob(["src/*.kt"]), module_name="probe", deps=[":dep"])
elide_kotlin_binary(name="app", srcs=["Main.kt"], deps=[":core"], main_class="MainKt")
'''
    (work / "src").mkdir()

    def contents():
        with zipfile.ZipFile(work / "bazel-bin/core.jar") as jar:
            return {name: jar.read(name) for name in jar.namelist()}

    try:
        for workers, sandboxed, selective in ((True, False, False), (False, False, False), (True, True, False), (True, False, True)):
            selected_build = build_file
            if selective:
                selected_build = selected_build.replace('name="core"', 'incremental_mode="on", abi_mode="combined", name="core"')
                for target in ("dep", "app"):
                    selected_build = selected_build.replace(f'name="{target}"', f'incremental_mode="off", abi_mode="combined", name="{target}"')
            (work / "BUILD.bazel").write_text(selected_build)
            (work / "Dep.kt").write_text("object Dep { const val OFFSET = 0 }; inline fun bonus() = 0\n")
            flags = [*sys.argv[1:], "--java_runtime_version=remotejdk_21",
                     "--tool_java_runtime_version=remotejdk_21", "--disk_cache=", "--remote_cache=",
                     "--remote_executor=", "--worker_max_instances=ElideKotlinc=1", "--@rules_elide//config/kotlinc:incremental=" + str(not selective).lower(),
                     "--@rules_elide//elide:prune_unused_inputs=" + str(selective).lower(),
                     "--@rules_elide//config/kotlinc:abi_compile_avoidance=true",
                     "--@rules_elide//elide:use_workers=" + str(workers).lower(),
                     "--worker_sandboxing=" + str(sandboxed).lower()]
            subprocess.run(command + ["shutdown"], cwd=work, check=True)
            subprocess.run(command + ["clean"], cwd=work, check=True)

            def build(expected=None, fails=False, cached=False):
                extra = ["--disk_cache=" + str(work / f"action-cache-{workers}-{sandboxed}-{selective}")] if cached else []
                # Let both the header and full compile fail. Fail-fast cancellation
                # can bypass the adapter failure path and strand a sandboxed worker
                # slot in Bazel before the recovery build starts.
                if fails:
                    extra.append("--keep_going")
                result = subprocess.run(command + ["build", ":app", *flags, *extra,
                                                  "--execution_log_json_file=" + str(work / "execution.json")], cwd=work)
                assert (result.returncode != 0) == fails, (workers, sandboxed, result.returncode)
                if not fails:
                    actual = subprocess.check_output([str(work / "bazel-bin/app_launcher.sh")], cwd=work, text=True).strip()
                    assert actual == str(expected), (workers, sandboxed, actual, expected)

            def core_actions():
                decoder = json.JSONDecoder()
                text = (work / "execution.json").read_text()
                actions = []
                while text.strip():
                    entry, end = decoder.raw_decode(text.lstrip())
                    text = text.lstrip()[end:]
                    if entry.get("mnemonic") == "ElideKotlinc" and entry.get("targetLabel") == "//:core":
                        actions.append(entry)
                return actions

            (work / "src/A.kt").write_text("object A { fun value() = 1 + Dep.OFFSET + bonus(); class Removed }\n")
            (work / "src/B.kt").write_text("object B { fun value() = 2 }\n")
            (work / "Main.kt").write_text("fun main() { println(A.value() + B.value()) }\n")
            build(3)
            (work / "src/A.kt").write_text("object A { fun value() = 10 + Dep.OFFSET + bonus(); class Removed }\n")
            build(12)
            assert "B.class" in contents(), "Unchanged independent class disappeared"
            (work / "src/A.kt").write_text("object A { fun value() = 10 + Dep.OFFSET + bonus() }\n")
            build(12)
            assert "A$Removed.class" not in contents(), "Deleted nested class survived"
            (work / "src/A.kt").write_text("object A { fun value() = DOES_NOT_EXIST }\n")
            build(fails=True)
            (work / "src/A.kt").write_text("object A { fun value() = 20 + Dep.OFFSET + bonus() }\n")
            build(22)
            (work / "Dep.kt").write_text("object Dep { const val OFFSET = 5 }; inline fun bonus() = 0\n")
            build(27)
            unaffected = contents()["B.class"]
            (work / "Dep.kt").write_text("object Dep { const val OFFSET = 5 }; inline fun bonus() = 4\n")
            build(31)
            assert contents()["B.class"] == unaffected, "Unrelated class changed after dependency inline edit"
            (work / "Dep.kt").write_text("object Dep { const val OFFSET = 5; fun unused() = 7 }; inline fun bonus() = 4\n")
            build(31)
            (work / "Dep.kt").write_text("object Dep { const val OFFSET = 5 }; inline fun bonus() = 0\n")
            build(27)
            (work / "src/B.kt").unlink()
            (work / "src/C.kt").write_text("object C { fun value() = 3 }\n")
            (work / "Main.kt").write_text("fun main() { println(A.value() + C.value()) }\n")
            build(28)
            assert "B.class" not in contents(), "Deleted source class survived"
            assert "C.class" in contents(), "Added source class missing"
            (work / "BUILD.bazel").write_text(selected_build.replace('module_name="probe"', 'module_name="probe_changed"'))
            build(28)
            assert "META-INF/probe.kotlin_module" not in contents(), "Old compiler-option output survived"
            assert "META-INF/probe_changed.kotlin_module" in contents()
            # A cache hit changes Bazel outputs without notifying the resident IC
            # worker. Its next compile must use its own last successful state.
            cached_source = "object A { fun value() = 40 + Dep.OFFSET + bonus(); class CachedOnly }\n"
            (work / "src/A.kt").write_text(cached_source)
            build(48, cached=True)
            cached_output = contents()
            (work / "src/A.kt").write_text("object A { fun value() = 50 + Dep.OFFSET + bonus(); class WorkerOnly }\n")
            build(58, cached=True)
            assert "A$WorkerOnly.class" in contents()
            (work / "src/A.kt").write_text(cached_source)
            build(48, cached=True)
            actions = core_actions()
            assert len(actions) == 1 and actions[0].get("cacheHit"), "Core output was not restored from the action cache"
            assert contents() == cached_output, "Cache restoration changed class output"
            (work / "src/A.kt").write_text("object A { fun value() = 60 + Dep.OFFSET + bonus() }\n")
            build(68, cached=True)
            actions = core_actions()
            assert len(actions) == 1 and not actions[0].get("cacheHit"), "Post-cache edit did not execute the compiler"
            assert "A$CachedOnly.class" not in contents() and "A$WorkerOnly.class" not in contents()
            warm = contents()
            subprocess.run(command + ["shutdown"], cwd=work, check=True)
            subprocess.run(command + ["clean"], cwd=work, check=True)
            build(68)
            assert contents() == warm, "Warm IC output differs from cold worker output"
            (work / "src/C.kt").unlink()
            print(f"Native IC complete output: workers={workers}, sandboxed={sandboxed}, selective={selective}", flush=True)
    finally:
        subprocess.run(command + ["shutdown"], cwd=work)
