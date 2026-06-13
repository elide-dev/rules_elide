package elide.kotlin.builder

import java.io.File

object Fallback {
    fun command(stockBuilder: String, flagfile: String): List<String> =
        listOf(stockBuilder, "--flagfile=$flagfile")

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
