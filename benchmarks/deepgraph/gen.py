#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0
"""Generate a large, deep dependency-graph Bazel workspace for surfacing the
work-avoidance wins (cross-target ABI compile-avoidance, within-target
incremental compilation, critical-path depth) on the native elide_{kotlin,java}
rules. Trivial micro-fixtures can't show these — this one is meant to be big.

Topology (per language, under //<lang>/...):
  core            one module every layer depends on (max reverse-dep fan-out).
                  Holds the ABI/IC traps: an inline fun + a const (Kotlin) /
                  a `static final` constant (Java), plus generics and a plain
                  (body-only-editable) function.
  mod0..mod{L-1}  a chain (mod_i deps on core + mod_{i-1}) → depth L critical
                  path. Each module has W files. Files within a module are
                  INDEPENDENT (each references only core), so touching one file
                  should let IC recompile ~one of W. Each module's ENTRY file
                  (K{i}_0) additionally references mod_{i-1}'s entry — the
                  cross-target ABI edge that a body-vs-signature edit probes.
  app             deps on mod_{L-1} (the graph sink).

The generated workspace is self-contained (no external deps) and uses the local
elide via `elide.use(local_path=...)`. The workspace dir is meant to be
gitignored; this generator + README are the committed artifacts.

Usage:
  benchmarks/deepgraph/gen.py --elide /abs/path/to/elide \
      [--layers 16] [--width 32] [--langs kotlin,java] [--out <dir>]
"""
import argparse
import os
import shutil

REPO_REL = "../../.."  # benchmarks/deepgraph/ws -> repo root


def w(path, text):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w") as f:
        f.write(text)


# ---------- Kotlin ----------
def kt_core(d, width):
    w(f"{d}/Box.kt", """package core
class Box<T>(val value: T) { fun <R> map(f: (T) -> R): Box<R> = Box(f(value)) }
data class Rec(val a: Int, val b: String)
interface Base { fun id(): Int }
inline fun twice(x: Int, f: (Int, Int) -> Int): Int = f(x, x)
const val VERSION: Int = 1
fun base(n: Int): Int = n * 2
""")
    for k in range(width):
        w(f"{d}/Core{k}.kt",
          f"package core\nclass Core{k} : Base {{ override fun id(): Int = {k}\n  fun calc(): Int = base({k}) }}\n")


def kt_mod(d, i, width):
    prev = f"import mod{i-1}.K{i-1}_0\n" if i > 0 else ""
    prev_call = f" + K{i-1}_0().v()" if i > 0 else ""
    # entry file: references core (incl. inline + const) AND the previous module.
    w(f"{d}/K{i}_0.kt", f"""package mod{i}
import core.Box
import core.twice
import core.VERSION
import core.base
{prev}class K{i}_0 {{
  fun v(): Int {{
    val b = Box(VERSION + {i})
    return twice(b.value) {{ x, y -> x + y }} + base({i}){prev_call}
  }}
}}
""")
    # remaining files: independent, reference only core (IC: touch 1 -> recompile 1).
    for j in range(1, width):
        w(f"{d}/K{i}_{j}.kt", f"""package mod{i}
import core.Box
import core.Core{j % max(1, width)}
class K{i}_{j} {{ fun v(): Int = Box({i} * 1000 + {j}).map {{ it + Core{j % max(1, width)}().id() }}.value }}
""")



# ---------- Java ----------
def java_core(d, width):
    w(f"{d}/Box.java", """package core;
public class Box<T> { public final T value; public Box(T v){this.value=v;}
  public <R> Box<R> map(java.util.function.Function<T,R> f){ return new Box<>(f.apply(value)); } }
""")
    w(f"{d}/Consts.java", "package core;\npublic final class Consts { public static final int VERSION = 1; }\n")
    w(f"{d}/Util.java", "package core;\npublic final class Util { public static int base(int n){ return n*2; } }\n")
    w(f"{d}/Base.java", "package core;\npublic interface Base { int id(); }\n")
    for k in range(width):
        w(f"{d}/Core{k}.java",
          f"package core;\npublic class Core{k} implements Base {{ public int id(){{return {k};}} public int calc(){{return Util.base({k});}} }}\n")


def java_mod(d, i, width):
    prev_imp = f"import mod{i-1}.K{i-1}_0;\n" if i > 0 else ""
    prev_call = f" + new K{i-1}_0().v()" if i > 0 else ""
    w(f"{d}/K{i}_0.java", f"""package mod{i};
import core.Box;
import core.Consts;
import core.Util;
{prev_imp}public class K{i}_0 {{
  public int v() {{
    Box<Integer> b = new Box<>(Consts.VERSION + {i});
    return b.value + Util.base({i}){prev_call};
  }}
}}
""")
    for j in range(1, width):
        w(f"{d}/K{i}_{j}.java", f"""package mod{i};
import core.Box;
import core.Core{j % max(1, width)};
public class K{i}_{j} {{
  public int v() {{ return new Box<>({i}*1000+{j}).map(x -> x + new Core{j % max(1, width)}().id()).value; }}
}}
""")


def java_build(name, deps):
    dl = "".join(f'        "{x}",\n' for x in deps)
    body = ('load("@rules_elide//elide:defs.bzl", "elide_java_library")\n\n'
            "elide_java_library(\n"
            f'    name = "{name}",\n'
            '    srcs = glob(["*.java"]),\n')
    if deps:
        body += f"    deps = [\n{dl}    ],\n"
    body += '    visibility = ["//visibility:public"],\n)\n'
    return body


def gen_lang(root, lang, layers, width):
    if lang == "kotlin":
        core_fn, mod_fn, build_fn = kt_core, kt_mod, kt_build_clean
    else:
        core_fn, mod_fn, build_fn = java_core, java_mod, java_build
    base = f"{root}/{lang}"
    core_fn(f"{base}/core", width)
    w(f"{base}/core/BUILD.bazel", build_fn("core", []))
    for i in range(layers):
        mod_fn(f"{base}/mod{i}", i, width)
        deps = ["//%s/core" % lang] + (["//%s/mod%d" % (lang, i - 1)] if i > 0 else [])
        w(f"{base}/mod{i}/BUILD.bazel", build_fn("mod%d" % i, deps))
    # app: sink depending on the deepest module.
    app_dep = "//%s/mod%d" % (lang, layers - 1)
    if lang == "kotlin":
        w(f"{base}/app/K.kt", f"package app\nimport mod{layers-1}.K{layers-1}_0\nclass App {{ fun run(): Int = K{layers-1}_0().v() }}\n")
    else:
        w(f"{base}/app/App.java", f"package app;\nimport mod{layers-1}.K{layers-1}_0;\npublic class App {{ public int run(){{ return new K{layers-1}_0().v(); }} }}\n")
    w(f"{base}/app/BUILD.bazel", build_fn("app", [app_dep]))


# clean kotlin BUILD (the inline kt_build above had a branch bug; use this).
def kt_build_clean(name, deps):
    dl = "".join(f'        "{x}",\n' for x in deps)
    body = ('load("@rules_elide//elide:defs.bzl", "elide_kotlin_library")\n\n'
            "elide_kotlin_library(\n"
            f'    name = "{name}",\n'
            '    srcs = glob(["*.kt"]),\n')
    if deps:
        body += f"    deps = [\n{dl}    ],\n"
    body += '    visibility = ["//visibility:public"],\n)\n'
    return body


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--elide", required=True, help="abs path to the elide binary (for elide.use local_path)")
    ap.add_argument("--layers", type=int, default=16)
    ap.add_argument("--width", type=int, default=32)
    ap.add_argument("--langs", default="kotlin,java")
    ap.add_argument("--out", default=os.path.join(os.path.dirname(os.path.abspath(__file__)), "ws"))
    args = ap.parse_args()

    langs = [x.strip() for x in args.langs.split(",") if x.strip()]
    out = os.path.abspath(args.out)
    if os.path.exists(out):
        shutil.rmtree(out)
    os.makedirs(out)

    w(f"{out}/.bazelrc", "common --enable_bzlmod\nbuild --incompatible_strict_action_env\n")
    elide_root = os.path.dirname(os.path.dirname(os.path.realpath(args.elide)))  # dist root for elide.use
    repo_root = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))  # rules_elide root
    w(f"{out}/MODULE.bazel", f"""module(name = "deepgraph")

bazel_dep(name = "rules_elide", version = "0.0.0")
local_path_override(module_name = "rules_elide", path = "{repo_root}")

bazel_dep(name = "rules_java", version = "9.6.1")
bazel_dep(name = "rules_kotlin", version = "2.3.20")

elide = use_extension("@rules_elide//elide:extensions.bzl", "elide")
elide.use(local_path = "{elide_root}")
use_repo(elide, "elide_toolchains")
register_toolchains("@elide_toolchains//:all")
""")

    total = 0
    for lang in langs:
        gen_lang(out, lang, args.layers, args.width)
        total += args.width + args.layers * args.width + 1
    print(f"generated {len(langs)} lang(s) x {args.layers} layers x {args.width} width  (~{total} source files) at {out}")
    print(f"elide dist root: {elide_root}")


if __name__ == "__main__":
    main()
