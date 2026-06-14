package elide.kotlin.builder

import java.io.File
import java.util.zip.ZipFile

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
    /**
     * Unpacks the given source jars into [into] and returns the paths of the
     * extracted `.kt`/`.java` files.
     *
     * rules_kotlin delivers KAPT/KSP-generated sources to the post-processing
     * compile via `--source_jars` (`CompileRequest.sourceJars`). `elide kotlinc`
     * does not accept a source jar directly, so they must be unpacked and added
     * to the compile's source set — needed for the `.kt` to RESOLVE references to
     * generated symbols (e.g. Truffle DSL `*NodeGen`). The generated classes
     * themselves are emitted by the KAPT step's `generated_class_jar` and merged
     * by rules_kotlin, so these extracted sources are resolution inputs only.
     */
    fun extractSourceJars(sourceJars: List<String>, into: File): List<String> {
        val extracted = mutableListOf<String>()
        for (jar in sourceJars) {
            ZipFile(File(jar)).use { zf ->
                val entries = zf.entries()
                while (entries.hasMoreElements()) {
                    val entry = entries.nextElement()
                    if (entry.isDirectory) continue
                    if (!entry.name.endsWith(".kt") && !entry.name.endsWith(".java")) continue
                    val dest = File(into, entry.name)
                    dest.parentFile?.mkdirs()
                    zf.getInputStream(entry).use { ins -> dest.outputStream().use(ins::copyTo) }
                    extracted += dest.path
                }
            }
        }
        return extracted
    }

    fun plan(req: CompileRequest, elidePath: String, extraSources: List<String> = emptyList()): List<List<String>> {
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
        // Generated sources unpacked from --source_jars (KAPT/KSP), for resolution.
        kt += extraSources
        cmds += kt

        // --- srcjar: pack sources when requested ---
        req.srcjar?.let { sj ->
            cmds += listOf(elidePath, "jar", "--", "--create", "--file", sj) + req.sources
        }

        return cmds
    }

    /**
     * Executes each command from [plan] sequentially, capturing merged stdout+stderr to a temp
     * file (avoids deadlocking on the OS pipe buffer; never writes to this process's stdout,
     * which carries the Bazel persistent-worker WorkResponse protocol).
     *
     * Returns `(exitCode, capturedOutput)`. The caller is responsible for surfacing the output —
     * in worker/RBE mode it must go into `WorkResponse.output` (Bazel does not carry the worker
     * process's own stderr), so we RETURN it rather than print it here. Mirrors `Fallback.run`.
     */
    fun run(cmds: List<List<String>>, workDir: File): Pair<Int, String> {
        val output = StringBuilder()
        for (c in cmds) {
            val log = File.createTempFile("elide-compile", ".log")
            try {
                val p = ProcessBuilder(c)
                    .directory(workDir)
                    .redirectErrorStream(true)
                    .redirectOutput(log)
                    .start()
                val code = p.waitFor()
                output.append(log.readText())
                if (code != 0) return code to output.toString()
            } finally {
                log.delete()
            }
        }
        return 0 to output.toString()
    }
}
