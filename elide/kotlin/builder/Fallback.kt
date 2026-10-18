package elide.kotlin.builder

import java.io.File

object Fallback {
    // kapt's `ModuleManipulationUtilsKt` calls `sun.misc.Unsafe::staticFieldBase`
    // to reflectively open the `jdk.compiler` module so annotation processors can
    // reach `com.sun.tools.javac.*` internals. On JDK 23+ that emits a terminal-
    // deprecation warning (JEP 471). `--sun-misc-unsafe-memory-access=allow`
    // silences it cleanly; we route it through the java_binary stub's
    // `--wrapper_script_flag=--jvm_flag=` passthrough so it lands as a real JVM
    // launch flag (no env var, no `Picked up …` notice). See WHIPLASH#1131.
    //
    // The option only exists on JDK 23+; passing it to an older `java` launcher is
    // a fatal "Unrecognized option", so gate on the feature version of the JDK the
    // stock builder runs on — its own java_binary runtime, which need not match the
    // shim's (e.g. rules_kotlin's builder on remotejdk11 under an Elide JDK 25 shim).
    private const val UNSAFE_SILENCER =
        "--wrapper_script_flag=--jvm_flag=--sun-misc-unsafe-memory-access=allow"

    internal fun unsafeSilencer(jdkFeature: Int): List<String> =
        if (jdkFeature >= 23) listOf(UNSAFE_SILENCER) else emptyList()

    fun command(
        stockBuilder: String,
        flagfile: String,
        jdkFeature: Int = Runtime.version().feature(),
    ): List<String> =
        listOf(stockBuilder) + unsafeSilencer(jdkFeature) + "--flagfile=$flagfile"

    private val builderFeatures = java.util.concurrent.ConcurrentHashMap<String, Int>()

    /** Feature version from `java -version` output (`"1.8.0_402"` -> 8, `"21.0.3"` -> 21); 0 if unknown. */
    fun parseJavaFeature(versionOutput: String): Int {
        val v = Regex("version \"([^\"]+)\"").find(versionOutput)?.groupValues?.get(1) ?: return 0
        val parts = v.split('.', '-', '_', '+')
        return (if (parts[0] == "1") parts.getOrNull(1) else parts[0])?.toIntOrNull() ?: 0
    }

    /** JDK feature version the [stockBuilder] java_binary launches on, probed once; 0 if unknown. */
    fun builderJdkFeature(stockBuilder: String, workDir: File): Int = builderFeatures.getOrPut(stockBuilder) {
        runCatching {
            val javabin = capture(listOf(stockBuilder, "--print_javabin"), workDir).trim().lines().last()
            parseJavaFeature(capture(listOf(javabin, "-version"), workDir))
        }.getOrDefault(0)
    }

    private fun capture(cmd: List<String>, workDir: File): String {
        val out = File.createTempFile("elide-fallback-probe", ".txt")
        try {
            ProcessBuilder(cmd).directory(workDir).redirectErrorStream(true).redirectOutput(out).start().waitFor()
            return out.readText()
        } finally {
            out.delete()
        }
    }

    /** One-shot delegation: returns (exitCode, capturedOutput). Output is captured
     *  (NOT written to this process's stdout — that carries the worker protocol). */
    fun run(stockBuilder: String, flagfile: String, workDir: File): Pair<Int, String> {
        val log = File.createTempFile("elide-fallback", ".log")
        try {
            val p = ProcessBuilder(command(stockBuilder, flagfile, builderJdkFeature(stockBuilder, workDir)))
                .directory(workDir)
                .redirectErrorStream(true)
                .redirectOutput(log)
                .start()
            val code = p.waitFor()
            return code to log.readText()
        } finally {
            log.delete()
        }
    }
}
