package elide.kotlin.builder

import com.google.devtools.build.lib.worker.WorkerProtocol.Input
import com.google.devtools.build.lib.worker.WorkerProtocol.WorkRequest
import com.google.devtools.build.lib.worker.WorkerProtocol.WorkResponse
import java.io.OutputStream
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicInteger

/**
 * A resident `elide kotlinc --persistent_worker` subprocess that the builder
 * forwards kotlinc compiles to, so the Elide native image — and its warm Kotlin
 * compiler and digest-driven incremental caches — stays hot across requests
 * instead of paying native-image startup (and a cold compiler) on every compile.
 *
 * Protocol: length-delimited Bazel `WorkerProtocol` (the same proto the builder
 * speaks to Bazel in [Worker]). We write a [WorkRequest] to Elide's stdin and
 * read a [WorkResponse] from its stdout. Elide's stderr is inherited — the
 * protocol stream is stdout; stderr is diagnostics. The forwarded request's
 * `arguments` are the kotlinc argv (see [ElideCompile.kotlincWorkerArgs]) and
 * its `inputs` carry path+digest so Elide's digest-driven IC (WHIPLASH#1112)
 * engages.
 *
 * Singleplex: the builder drives one compile at a time, so [compile] is
 * synchronized and reads the matching response inline. `requestId` is tracked so
 * this extends to multiplex forwarding (Elide multiplexing is implemented and
 * safe) without a protocol change.
 *
 * Failure handling: any process or IO error kills the connection and rethrows;
 * the caller falls back to a one-shot `elide kotlinc` invocation and a fresh
 * resident process starts on the next [compile]. A dead pipe never wedges.
 *
 * Lifecycle: [close] shuts Elide's stdin (clean EOF) so it exits cleanly — which
 * also lets a `--pgo-instrument` binary flush its `default.iprof`
 * (docs/superpowers/specs/2026-06-20-kotlinc-persistent-worker-pgo.md). The
 * optional [recordSink] tees every forwarded request byte-for-byte for offline
 * PGO replay (`elide kotlinc --persistent_worker < captured.bin`).
 */
class ElideWorker(
    private val elidePath: String,
    private val recordSink: OutputStream? = null,
) : AutoCloseable {
    private var process: Process? = null
    private val nextId = AtomicInteger(1)

    @Synchronized
    private fun ensureStarted(): Process {
        process?.let { if (it.isAlive) return it }
        // `--safe-close` (top-level) guarantees a clean shutdown on stdin EOF,
        // which is what flushes a `--pgo-instrument` build's `default.iprof`. It
        // is harmless otherwise, so we always pass it.
        val p = ProcessBuilder(elidePath, "--safe-close", "kotlinc", "--persistent_worker")
            // stdout is the WorkResponse stream (piped); stderr is diagnostics.
            .redirectError(ProcessBuilder.Redirect.INHERIT)
            .start()
        process = p
        return p
    }

    /**
     * Forwards one kotlinc compile to the resident process; returns
     * `(exitCode, output)`. [args] is the kotlinc argv WITHOUT the leading
     * `elide kotlinc` identity or one-shot `--` framing; [inputs] carry
     * path+digest. Throws on a dead process or protocol desync — callers fall
     * back to a one-shot invocation.
     */
    @Synchronized
    fun compile(args: List<String>, inputs: List<Input>): Pair<Int, String> {
        val p = ensureStarted()
        val id = nextId.getAndIncrement()
        val req = WorkRequest.newBuilder()
            .addAllArguments(args)
            .addAllInputs(inputs)
            .setRequestId(id)
            .build()
        try {
            val stdin = p.outputStream
            req.writeDelimitedTo(stdin)
            stdin.flush()
            recordSink?.let { req.writeDelimitedTo(it); it.flush() }

            val resp = WorkResponse.parseDelimitedFrom(p.inputStream)
                ?: throw IllegalStateException(
                    "resident elide closed stdout (exit=${runCatching { p.exitValue() }.getOrNull()})",
                )
            // Singleplex: ids must line up (0 = unset is also accepted); a
            // mismatch means the streams desynced — bail so we restart clean.
            check(resp.requestId == id || resp.requestId == 0) {
                "resident elide response id ${resp.requestId} != request id $id"
            }
            return resp.exitCode to resp.output
        } catch (e: Exception) {
            kill()
            throw e
        }
    }

    @Synchronized
    private fun kill() {
        process?.destroyForcibly()
        process = null
    }

    /** Clean shutdown: stdin EOF → Elide exits (and flushes any PGO profile). */
    @Synchronized
    override fun close() {
        val p = process ?: return
        runCatching { p.outputStream.close() } // EOF → clean exit
        if (!p.waitFor(30, TimeUnit.SECONDS)) p.destroyForcibly()
        process = null
        recordSink?.let { runCatching { it.close() } }
    }
}
