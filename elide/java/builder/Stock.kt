package elide.java.builder

import com.google.devtools.build.lib.worker.WorkerProtocol.Input
import com.google.devtools.build.lib.worker.WorkerProtocol.WorkRequest
import com.google.devtools.build.lib.worker.WorkerProtocol.WorkResponse
import java.io.File
import java.util.concurrent.TimeUnit

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

    // A warm child `JavaBuilder --persistent_worker`, so stock-routed compiles keep a hot JIT.
    private var child: Process? = null

    private fun worker(): Process = child?.takeIf { it.isAlive } ?: ProcessBuilder(command("--persistent_worker"))
        .redirectError(ProcessBuilder.Redirect.INHERIT)
        .start()
        .also { child = it }

    /** Forwards one request to the warm child; restarts it once if it died. */
    fun forward(args: List<String>, inputs: List<Input>): Pair<Int, String> {
        repeat(2) { attempt ->
            val p = worker()
            try {
                WorkRequest.newBuilder().addAllArguments(args).addAllInputs(inputs).build().writeDelimitedTo(p.outputStream)
                p.outputStream.flush()
                val response = WorkResponse.parseDelimitedFrom(p.inputStream) ?: error("JavaBuilder worker closed its stream")
                return response.exitCode to response.output
            } catch (e: Exception) {
                p.destroyForcibly()
                child = null
                if (attempt == 1) throw e
            }
        }
        error("unreachable")
    }

    override fun close() {
        child?.let { p ->
            try { p.outputStream.close() } catch (_: Exception) {}
            if (!p.waitFor(5, TimeUnit.SECONDS)) p.destroyForcibly()
        }
    }
}
