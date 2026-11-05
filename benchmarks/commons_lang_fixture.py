"""Production Commons Lang sources with a generated downstream consumer graph."""
import hashlib
import os
import shutil
import subprocess
import zipfile

SCENARIOS = ("no_op", "comment", "body", "private_member", "internal_module_api",
             "public_module_api", "multi_file_body")


def snapshot(checkout):
    """Read once; benchmark only copies, never edits the source checkout."""
    checkout = checkout.resolve()
    root = checkout / "src/main/java"
    sources = {p.relative_to(root).as_posix(): p.read_bytes() for p in sorted(root.rglob("*.java"))}
    if not sources or "org/apache/commons/lang3/StringUtils.java" not in sources:
        raise ValueError(f"Not a Commons Lang source checkout: {checkout}")
    digest = hashlib.sha256()
    for name, data in sources.items():
        digest.update(name.encode() + b"\0" + data + b"\0")
    revision = subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=checkout, text=True).strip()
    dirty = bool(subprocess.check_output(["git", "status", "--porcelain"], cwd=checkout, text=True).strip())
    return sources, {"project": "Apache Commons Lang", "revision": revision,
                     "checkout_dirty": dirty, "source_sha256": digest.hexdigest(),
                     "source_files": len(sources), "consumer_graph": "generated"}


def install(work, generated, production, fanout):
    sources = {p: text for p, text in generated.items() if p.parent.name != "core"}
    core = work / "core"
    build = (core / "BUILD.bazel").read_text()
    shutil.rmtree(core)
    core.mkdir()
    # Preserve the selected rule; replace only the generated source list.
    start = build.index("srcs=")
    end = build.index(", deps=", start)
    (core / "BUILD.bazel").write_text(build[:start] + 'srcs=glob(["**/*.java"])' + build[end:])
    for name, data in production.items():
        path = core / name
        path.parent.mkdir(parents=True, exist_ok=True)
        sources[path] = data.decode("utf-8")
    facade = work / "facade/Facade.java"
    sources[facade] = '''package facade;
public final class Facade {
  public static int value() {
    return (org.apache.commons.lang3.StringUtils.isEmpty("x") ? 1 : 0)
        + (org.apache.commons.lang3.CharUtils.isAscii('a') ? 1 : 0)
        + (org.apache.commons.lang3.BooleanUtils.isTrue(Boolean.TRUE) ? 1 : 0);
  }
}
'''
    app = work / "app/App.java"
    original = sources[app]
    index = original.rfind("}")
    sources[app] = original[:index] + f'''public static void main(String[] args) {{
      if (value() != {2 * fanout}) throw new AssertionError("Stale or incorrect consumer output: " + value());
    }}
''' + original[index:]
    return sources


def replace_once(text, old, new):
    if text.count(old) != 1:
        raise ValueError(f"Source revision does not match benchmark edit: {old!r}")
    return text.replace(old, new, 1)


def mutate(sources, scenario, nonce):
    if scenario == "no_op":
        return
    by_name = {path.name: path for path in sources}
    path = by_name["Facade.java" if scenario == "public_module_api" else "StringUtils.java"]
    text = sources[path]
    if scenario == "comment":
        text += f"\n// Benchmark edit {nonce}\n"
    elif scenario in ("body", "multi_file_body"):
        text = replace_once(text, "return cs == null || cs.length() == 0;",
                            "return cs == null || cs.isEmpty();")
        # Unique inputs prevent restored samples from reusing an earlier edit's action.
        text += f"\n// Benchmark edit {nonce}\n"
    else:
        visibility = "private" if scenario == "private_member" else "public"
        index = text.rfind("}")
        text = text[:index] + f"{visibility} static int benchmarkAdded{nonce}() {{ return {nonce}; }}\n" + text[index:]
    path.write_text(text)
    if scenario == "multi_file_body":
        edits = {
            "CharUtils.java": ("return ch < 128;", "return ch <= 127;"),
            "BooleanUtils.java": ("return Boolean.TRUE.equals(bool);", "return bool != null && bool.booleanValue();"),
        }
        for name, (old, new) in edits.items():
            path = by_name[name]
            path.write_text(replace_once(sources[path], old, new) + f"\n// Benchmark edit {nonce}\n")


def verify(work, fanout, mode, java, log):
    jars = ["core/libcore.jar", "spare/libspare.jar", "facade/libfacade.jar", "app/libapp.jar",
            *[f"clients/libclient{i}.jar" for i in range(fanout)]]
    if mode != "vanilla":
        jars = [jar.replace("/lib", "/", 1) for jar in jars]
    paths = [work / "bazel-bin" / jar for jar in jars]
    for path in paths:
        if not path.is_file():
            raise FileNotFoundError(f"Runtime jar missing: {path}")
        with zipfile.ZipFile(path) as archive:
            for name in archive.namelist():
                if name.endswith(".class"):
                    major = int.from_bytes(archive.read(name)[6:8], "big")
                    if major != 65:
                        raise AssertionError(f"Expected Java 21 bytecode (65), got {major}: {path}!{name}")
    classpath = os.pathsep.join(map(str, paths))
    with log.open("w") as stream:
        subprocess.run([java, "-cp", classpath, "app.App"], check=True, stdout=stream, stderr=subprocess.STDOUT)
