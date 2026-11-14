package elide.java.builder

import com.google.devtools.build.lib.worker.WorkerProtocol.Input
import elide.builder.worker.ResidentWorker
import java.io.File

/** The stock rules_java JavaBuilder, run with the toolchain's JVM options. */
class Stock(private val java: String, private val jar: String, private val jvmOpts: List<String>) : AutoCloseable {
    private fun command(vararg tail: String) = listOf(java) + jvmOpts + listOf("-jar", jar) + tail

    /** One-shot compile (non-worker execution). */
    fun run(args: List<String>, wd: File): Pair<Int, String> {
        val log = File.createTempFile("javabuilder", ".log")
        try {
            val p = ProcessBuilder(command(*args.toTypedArray())).directory(wd).redirectErrorStream(true).redirectOutput(log).start()
            return p.waitFor() to log.readText()
        } finally {
            log.delete()
        }
    }

    // A warm child `JavaBuilder --persistent_worker`, so stock-routed compiles keep a hot JIT. JavaBuilder
    // serves concurrent requests itself, so one child also covers a multiplex shim.
    private val child = ResidentWorker({
        ProcessBuilder(command("--persistent_worker")).redirectError(ProcessBuilder.Redirect.INHERIT).start()
    })

    /** Forwards one request to the warm child; restarts it once if it died. */
    fun forward(args: List<String>, inputs: List<Input>): Pair<Int, String> =
        try {
            child.compile(args, inputs)
        } catch (_: Exception) {
            child.compile(args, inputs)
        }

    override fun close() = child.close()
}
