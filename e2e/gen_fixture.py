#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0
"""Generate the shared e2e benchmark fixture.

Emits N self-contained, inference-heavy Kotlin sources and N Java sources into
`<workspace>/gen/kotlin/` and `<workspace>/gen/java/`. The files are committed
(not generated at bench time) so the bench runner builds a fixed, identical
workload in both `e2e/vanilla` (no-Elide baseline) and `e2e/integration` (Elide).

Regenerate both workspaces (keep them identical):
    python e2e/gen_fixture.py e2e/vanilla 200
    python e2e/gen_fixture.py e2e/integration 200

Files are flat in `package gen`; each is independent (no cross-file edges), so a
1-file edit dirties only itself and the whole set compiles in parallel.
"""

import shutil
import sys
from pathlib import Path


def _kotlin(i: int, tag: str) -> str:
    # `tag` (zero-padded id) names the type + file; `i` feeds numeric literals.
    buckets = 3 + i % 5
    take = 8 + i % 7
    return f"""package gen

// Generated benchmark fixture — do not edit by hand (see e2e/gen_fixture.py).
object Gen{tag} {{
  fun transform(xs: List<Int>): Map<String, List<Int>> =
    xs.groupBy {{ "bucket${{it % {buckets}}}" }}.mapValues {{ (_, v) -> v.sorted() }}

  fun pipeline(n: Int): List<Pair<Int, String>> =
    (0 until n).map {{ it to "v{tag}_$it" }}.filter {{ it.first % 2 == 0 }}

  fun reduce(items: List<Pair<String, Int>>): Map<String, Int> =
    items.fold(mutableMapOf<String, Int>()) {{ acc, (k, v) -> acc.apply {{ merge(k, v, Int::plus) }} }}

  fun seed(): List<Int> = generateSequence({i}) {{ it + 1 }}.take({take}).toList()
}}
"""


def _java(i: int, tag: str) -> str:
    return f"""package gen;

import java.util.List;
import java.util.Map;
import java.util.stream.Collectors;
import java.util.stream.IntStream;

// Generated benchmark fixture — do not edit by hand (see e2e/gen_fixture.py).
public final class GenJava{tag} {{
  private GenJava{tag}() {{}}

  public static Map<String, Integer> counts(List<String> xs) {{
    return xs.stream().collect(Collectors.groupingBy(s -> s, Collectors.summingInt(s -> 1)));
  }}

  public static int total(int[] a) {{
    int s = 0;
    for (int x : a) s += x;
    return s + {i};
  }}

  public static List<Integer> evens(int n) {{
    return IntStream.range(0, n).filter(x -> x % 2 == 0).boxed().collect(Collectors.toList());
  }}
}}
"""


def main() -> None:
    if len(sys.argv) != 3:
        sys.exit("usage: gen_fixture.py <workspace-dir> <N>")
    ws = Path(sys.argv[1])
    n = int(sys.argv[2])
    kt_dir = ws / "gen" / "kotlin"
    java_dir = ws / "gen" / "java"
    for d in (kt_dir, java_dir):
        if d.exists():
            shutil.rmtree(d)
        d.mkdir(parents=True)
    width = len(str(n - 1))
    for i in range(n):
        tag = str(i).zfill(width)
        (kt_dir / f"Gen{tag}.kt").write_text(_kotlin(i, tag))
        (java_dir / f"GenJava{tag}.java").write_text(_java(i, tag))
    print(f"Wrote {n} Kotlin + {n} Java sources under {ws}/gen/")


if __name__ == "__main__":
    main()
