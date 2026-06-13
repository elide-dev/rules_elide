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
     * Plugin ID for the jvm-abi-gen Kotlin compiler plugin bundled with Elide.
     * Used with `-Xplugin=<jar>` and `-P plugin:<id>:outputDir=<path>`.
     */
    private const val JVM_ABI_GEN_PLUGIN_ID = "org.jetbrains.kotlin.jvm.abi"

    /**
     * Relative path within the Elide distribution root to the jvm-abi-gen plugin jar.
     * The distribution root is `File(elidePath).parentFile.parentFile` (binary lives in `bin/`).
     * The Kotlin version directory is discovered at runtime via [findJvmAbiGenJar].
     */
    private const val JVM_ABI_GEN_RELATIVE = "lib/resources/kotlin"

    /**
     * Locates the jvm-abi-gen.jar bundled in the Elide distribution.
     * Returns `null` if not found (graceful degradation).
     */
    internal fun findJvmAbiGenJar(elidePath: String): File? {
        val distRoot = File(elidePath).parentFile?.parentFile ?: return null
        val kotlinDir = distRoot.resolve(JVM_ABI_GEN_RELATIVE)
        if (!kotlinDir.isDirectory) return null
        // There is exactly one Kotlin version directory; pick the first one found.
        val versionDir = kotlinDir.listFiles()?.firstOrNull { it.isDirectory } ?: return null
        return versionDir.resolve("lib/jvm-abi-gen.jar").takeIf { it.isFile }
    }

    /**
     * Returns the list of subprocess argv lists to execute for the given [req].
     * Pure — no side effects; safe to unit-test without a real Elide binary.
     *
     * Emits:
     *  1. An `elide kotlinc` command to compile sources to [CompileRequest.output].
     *     When [CompileRequest.abiJar] is set AND `jvm-abi-gen.jar` is discoverable
     *     in the Elide distribution, injects `-Xplugin=<jar>` and
     *     `-P plugin:org.jetbrains.kotlin.jvm.abi:outputDir=<abiJar>` into the
     *     kotlinc flags so both the full jar and the ABI-stripped jar are produced
     *     in one compiler pass. Verified against Elide 1.3.0 / Kotlin 2.4.0.
     *  2. An `elide jar` command to pack sources into [CompileRequest.srcjar], if set.
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
        // ABI jar via the jvm-abi-gen plugin embedded in the Elide distribution.
        // Invocation form verified against Elide 1.3.0:
        //   elide kotlinc -- -d <out.jar>
        //     -Xplugin=<distRoot>/lib/resources/kotlin/<kver>/lib/jvm-abi-gen.jar
        //     -P plugin:org.jetbrains.kotlin.jvm.abi:outputDir=<abi.jar>
        //     <srcs>
        req.abiJar?.let { abiJarPath ->
            val distRoot = File(elidePath).parentFile?.parentFile
            val pluginJar = findJvmAbiGenJar(elidePath)
                ?: error(
                    "abiJar requested ($abiJarPath) but jvm-abi-gen.jar not found under the " +
                    "Elide distribution at $distRoot; cannot produce the ABI jar"
                )
            kt += "-Xplugin=${pluginJar.path}"
            kt += "-P"
            kt += "plugin:$JVM_ABI_GEN_PLUGIN_ID:outputDir=$abiJarPath"
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
     * Executes each command from [plan] sequentially, capturing output to a temp file to avoid
     * deadlocking on the OS pipe buffer. On failure the captured output is written to stderr
     * (never to stdout, which carries the Bazel persistent-worker WorkResponse protocol).
     * Returns 0 on success, or the first non-zero exit code encountered.
     */
    fun run(cmds: List<List<String>>, workDir: File): Int {
        for (c in cmds) {
            val log = File.createTempFile("elide-compile", ".log")
            try {
                val p = ProcessBuilder(c)
                    .directory(workDir)
                    .redirectErrorStream(true)
                    .redirectOutput(log)
                    .start()
                val code = p.waitFor()
                if (code != 0) {
                    System.err.print(log.readText())
                    return code
                }
            } finally {
                log.delete()
            }
        }
        return 0
    }
}
