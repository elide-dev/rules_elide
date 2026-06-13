package elide.kotlin.builder

import java.io.File

/**
 * Constructs and executes Elide subprocess invocations for Kotlin compilation.
 *
 * The command form mirrors how rules_elide invokes elide in compile_common.bzl:
 *   elide kotlinc -- -d <out> -classpath <cp> [-module-name <m>] [-Xfriend-paths=...] <passthrough> <srcs>
 *
 * The `--` separator is required for one-shot invocations (worker mode omits it).
 */
object ElideCompile {
    /**
     * Returns the list of subprocess argv lists to execute for the given [req].
     * Pure — no side effects; safe to unit-test without a real Elide binary.
     *
     * Currently emits:
     *  1. An `elide kotlinc` command to compile sources to [CompileRequest.output].
     *  2. An `elide jar` command to pack sources into [CompileRequest.srcjar], if set.
     *
     * // TODO(abijar): pending verified jvm-abi-gen invocation; wire in once the exact
     * //   `-Xplugin=`/`-P plugin:jvm-abi-gen:outputDir=` form is confirmed against
     * //   the embedded plugin in Elide 1.3.x.
     */
    fun plan(req: CompileRequest, elidePath: String): List<List<String>> {
        val cmds = mutableListOf<List<String>>()
        val sep = File.pathSeparator

        // --- kotlinc command ---
        val kt = mutableListOf(elidePath, "kotlinc", "--", "-d", req.output ?: error("--output required"))
        if (req.classpath.isNotEmpty()) {
            kt += "-classpath"
            kt += req.classpath.joinToString(sep)
        }
        req.moduleName?.let { kt += listOf("-module-name", it) }
        if (req.friendPaths.isNotEmpty()) {
            kt += "-Xfriend-paths=" + req.friendPaths.joinToString(",")
        }
        kt += req.passthroughFlags
        kt += req.sources
        cmds += kt

        // --- srcjar: pack sources when requested ---
        req.srcjar?.let { sj ->
            cmds += listOf(elidePath, "jar", "--", "--create", "--file", sj) + req.sources
        }

        return cmds
    }

    /**
     * Executes each command from [plan] sequentially, streaming stderr on failure.
     * Returns 0 on success, or the first non-zero exit code encountered.
     */
    fun run(cmds: List<List<String>>, workDir: File): Int {
        for (c in cmds) {
            val p = ProcessBuilder(c)
                .directory(workDir)
                .redirectErrorStream(true)
                .start()
            val out = p.inputStream.bufferedReader().readText()
            val code = p.waitFor()
            if (code != 0) {
                System.err.print(out)
                return code
            }
        }
        return 0
    }
}
