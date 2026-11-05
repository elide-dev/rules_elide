"""Exercise Kotlin JavaInfo dependencies with stock Java launchers."""
from pathlib import Path
import subprocess
import sys

work = Path(__file__).resolve().parent
for workers in ("true", "false"):
    for avoidance, combined in (("false", "false"), ("true", "false"), ("true", "true")):
        targets = ("stock_java_consumer", "stock_runtime_consumer")
        subprocess.run(["bazel", "build", *[":" + t for t in targets], *sys.argv[1:],
                        "--@rules_elide//elide:use_workers=" + workers,
                        "--@rules_elide//config/kotlinc:abi_compile_avoidance=" + avoidance,
                        "--@rules_elide//config/kotlinc:abi_from_compile=" + combined], cwd=work, check=True)
        for target in targets:
            output = subprocess.check_output([str(work / "bazel-bin" / target)], cwd=work, text=True).strip()
            assert output == "kotlin-interop-ok", (workers, avoidance, combined, target, output)
print("Stock Java compile/runtime consumers receive Kotlin stdlib in all worker/ABI modes.")
