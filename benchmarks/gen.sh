#!/usr/bin/env bash
# Generates N dummy Java + N dummy Kotlin source files under sources/.
# Each file is self-contained, no cross-deps, ensures consistent compile cost.
set -o errexit -o nounset -o pipefail

N="${1:-50}"
ROOT="$(cd "$(dirname "$0")" && pwd)"
SRC="${ROOT}/sources"

rm -rf "${SRC}"
mkdir -p "${SRC}/java/sample" "${SRC}/kotlin/sample"

for i in $(seq 1 "${N}"); do
  cat > "${SRC}/java/sample/JavaClass${i}.java" <<EOF
package sample;
public final class JavaClass${i} {
  private JavaClass${i}() {}
  public static int value() { return ${i}; }
  public static String label() { return "java-${i}"; }
}
EOF
  cat > "${SRC}/kotlin/sample/KotlinClass${i}.kt" <<EOF
package sample
object KotlinClass${i} {
  fun value(): Int = ${i}
  fun label(): String = "kotlin-${i}"
}
EOF
done

echo "Generated ${N} Java and ${N} Kotlin sources under ${SRC}."
