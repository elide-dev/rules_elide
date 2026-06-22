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
    // a fatal "Unrecognized option", so gate on the running feature version (the
    // shim and the fallback builder share the toolchain JDK).
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

    /** One-shot delegation: returns (exitCode, capturedOutput). Output is captured
     *  (NOT written to this process's stdout — that carries the worker protocol). */
    fun run(stockBuilder: String, flagfile: String, workDir: File): Pair<Int, String> {
        val log = File.createTempFile("elide-fallback", ".log")
        try {
            val p = ProcessBuilder(command(stockBuilder, flagfile))
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
