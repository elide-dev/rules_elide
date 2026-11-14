"""Benchmark the production KotlinBuilder module, with generated consumers."""
import hashlib
import json
import shutil
import subprocess
import zipfile

from commons_lang_fixture import replace_once

SCENARIOS = ("clean", "no_op", "comment", "body", "private_member",
             "internal_module_api", "public_module_api", "multi_file_body")


def snapshot(repo):
    root = repo / "elide/kotlin/builder"
    files = sorted([*root.glob("*.kt"), *root.glob("proto/*.proto")])
    sources = {p.relative_to(root).as_posix(): p.read_bytes() for p in files}
    digest = hashlib.sha256()
    for name, data in sources.items():
        digest.update(name.encode() + b"\0" + data + b"\0")
    return sources, {
        "project": "rules_elide KotlinBuilder", "revision": subprocess.check_output(
            ["git", "rev-parse", "HEAD"], cwd=repo, text=True).strip(),
        "checkout_dirty": bool(subprocess.check_output(
            ["git", "status", "--porcelain", "--untracked-files=no"], cwd=repo, text=True).strip()),
        "source_sha256": digest.hexdigest(), "source_files": len(sources),
        "kotlin_files": sum(p.endswith(".kt") for p in sources),
        "proto_files": sum(p.endswith(".proto") for p in sources),
        "consumer_graph": "generated", "jvm_target": "21",
    }


def install(work, generated, production, fanout):
    sources = {p: text for p, text in generated.items() if p.parent.name != "core"}
    core = work / "core"
    build = (core / "BUILD.bazel").read_text()
    shutil.rmtree(core)
    core.mkdir()
    start = build.index("srcs=")
    end = build.index(", deps=", start)
    build = build[:start] + 'srcs=glob(["*.kt"])' + build[end:]
    deps = ["//protocol:deps_java_proto", "//protocol:worker_protocol_java_proto"]
    (core / "BUILD.bazel").write_text(replace_once(build, "deps=[]", "deps=" + json.dumps(deps)))
    protocol = work / "protocol"
    protocol.mkdir(exist_ok=True)
    for name, data in production.items():
        path = protocol / name.removeprefix("proto/") if name.endswith(".proto") else core / name
        sources[path] = data.decode("utf-8")
    (protocol / "BUILD.bazel").write_text('''load("@protobuf//bazel:java_proto_library.bzl", "java_proto_library")
load("@protobuf//bazel:proto_library.bzl", "proto_library")
package(default_visibility=["//visibility:public"])
''' + "\n".join(
        f'proto_library(name="{name}_proto", srcs=["{name}.proto"])\n'
        f'java_proto_library(name="{name}_java_proto", deps=[":{name}_proto"])'
        for name in ("deps", "worker_protocol")))
    sources[work / "facade/Facade.kt"] = '''package facade
import elide.kotlin.builder.Flagfile
import elide.kotlin.builder.Router
import elide.kotlin.builder.Route
import elide.kotlin.builder.BuiltinPlugins
object Facade {
    fun value(): Int {
        val request = Flagfile.parse(listOf("--sources", "One.kt", "Two.kt"))
        check(Router.route(request).route == Route.FAST)
        check(Router.route(request.copy(compilerPluginClasspath = listOf("symbol-processing.jar"))).route == Route.FALLBACK)
        check(BuiltinPlugins.warning(emptyList()).isEmpty())
        check(BuiltinPlugins.warning(listOf(BuiltinPlugins.Rewrite("serialization.jar", "serialization"))).contains("serialization"))
        return request.sources.size
    }
}
'''
    app = work / "app/App.kt"
    text = sources[app]
    index = text.rfind("}")
    sources[app] = text[:index] + f'@JvmStatic fun main(args: Array<String>) {{ check(value() == {2 * fanout}); println("builder-consumer-ok") }}\n' + text[index:]
    build = work / "app/BUILD.bazel"
    build.write_text('load("@rules_java//java:defs.bzl", "java_binary")\n' + build.read_text() +
                     '\njava_binary(name="verify", main_class="app.App", runtime_deps=[":app"])\n')
    (work / "BUILD.bazel").write_text('load("@rules_kotlin//kotlin:core.bzl", "define_kt_toolchain")\ndefine_kt_toolchain(name="stock_kotlin", jvm_target="21")\n')
    for package in ("core", "spare", "facade", "clients", "app"):
        path = work / package / "BUILD.bazel"
        path.write_text(path.read_text().replace('elide_kotlin_library(', 'elide_kotlin_library(kotlinc_opts=["-jvm-target=21"], '))
    core_build = core / "BUILD.bazel"
    core_build.write_text(core_build.read_text().replace('name="core",', 'name="core", module_name="elide_kotlin_builder",'))
    return sources


def mutate(sources, scenario, nonce):
    if scenario in ("clean", "no_op"):
        return
    by_name = {p.name: p for p in sources}
    path = by_name["Facade.kt" if scenario == "public_module_api" else "Flagfile.kt"]
    text = sources[path]
    if scenario == "comment":
        text += f"\n// Benchmark edit {nonce}\n"
    elif scenario in ("body", "multi_file_body"):
        text = replace_once(text, 'if (t.startsWith("--")) {', "if (t.length >= 2 && t[0] == '-' && t[1] == '-') {")
        text += f"\n// Benchmark edit {nonce}\n"
    else:
        visibility = "private" if scenario == "private_member" else "public"
        index = text.rfind("}")
        text = text[:index] + f"{visibility} fun benchmarkAdded{nonce}(): Int = {nonce}\n" + text[index:]
    path.write_text(text)
    if scenario == "multi_file_body":
        for name, old, new in (
            ("Router.kt", "j.contains(it)", "j.indexOf(it) >= 0"),
            ("BuiltinPlugins.kt", "if (rewrites.isEmpty())", "if (rewrites.size == 0)"),
        ):
            path = by_name[name]
            path.write_text(replace_once(sources[path], old, new) + f"\n// Benchmark edit {nonce}\n")


def verify(work, fanout, mode, java, log):
    with zipfile.ZipFile(work / "bazel-bin/core/core.jar") as archive:
        classes = [name for name in archive.namelist() if name.endswith(".class")]
        if not classes:
            raise AssertionError("Production Kotlin module contains no classes")
        for name in classes:
            major = int.from_bytes(archive.read(name)[6:8], "big")
            if major != 65:
                raise AssertionError(f"Expected JVM 21 bytecode (65), got {major}: {name}")
    with log.open("w") as stream:
        result = subprocess.run([str(work / "bazel-bin/app/verify")], cwd=work, text=True,
                                stdout=subprocess.PIPE, stderr=stream, check=True)
        if result.stdout.strip() != "builder-consumer-ok":
            raise AssertionError(result.stdout)
        stream.write(result.stdout)
