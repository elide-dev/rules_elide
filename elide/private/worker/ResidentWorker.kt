package elide.builder.worker

import com.google.devtools.build.lib.worker.WorkerProtocol.Input
import com.google.devtools.build.lib.worker.WorkerProtocol.WorkRequest
import com.google.devtools.build.lib.worker.WorkerProtocol.WorkResponse
import java.io.OutputStream
import java.util.concurrent.CompletableFuture
import java.util.concurrent.ConcurrentHashMap
import java.util.concurrent.ExecutionException
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicInteger

/**
 * A resident persistent-worker subprocess that a builder shim forwards compiles
 * to: `elide <tool> --persistent_worker`, so the Elide native image and its
 * warm compiler stay hot instead of paying process startup on every compile, or
 * the stock builder a shim falls back to.
 *
 * Protocol: length-delimited Bazel `WorkerProtocol`. Requests are written to
 * the process's stdin and responses read from its stdout by one reader thread,
 * which matches them to callers by `request_id`. [compile] may therefore be
 * called from several threads at once; whether the compiles then overlap is up
 * to the process (Elide serves them one at a time, see [ResidentPool]). The
 * process's stderr is inherited.
 *
 * Failure handling: a process or IO error, or a response that matches no
 * caller, kills the process and fails every in-flight [compile]; the next
 * [compile] starts a fresh process.
 *
 * [close] shuts the process's stdin so it exits cleanly, which also lets a
 * `--pgo-instrument` Elide flush its profile. The optional [recordSink] tees
 * every forwarded request for offline replay.
 */
class ResidentWorker(
    private val start: () -> Process,
    private val recordSink: OutputStream? = null,
) : AutoCloseable {
    constructor(elidePath: String, tool: String, recordSink: OutputStream? = null) : this(
        {
            // `--safe-close` guarantees a clean shutdown on stdin EOF.
            ProcessBuilder(elidePath, "--safe-close", tool, "--persistent_worker")
                .redirectError(ProcessBuilder.Redirect.INHERIT)
                .start()
        },
        recordSink,
    )

    private class Connection(val process: Process) {
        val pending = ConcurrentHashMap<Int, CompletableFuture<WorkResponse>>()
    }

    private val lock = Any()
    private var connection: Connection? = null
    private val nextId = AtomicInteger(1)

    // Callers hold `lock`.
    private fun connect(): Connection {
        connection?.let { if (it.process.isAlive) return it }
        val c = Connection(start())
        connection = c
        Thread({ read(c) }, "resident-worker-reader").apply { isDaemon = true }.start()
        return c
    }

    private fun read(c: Connection) {
        try {
            while (true) {
                val response = WorkResponse.parseDelimitedFrom(c.process.inputStream)
                    ?: error("resident worker closed stdout (exit=${runCatching { c.process.exitValue() }.getOrNull()})")
                // An unset id is accepted only when exactly one request is in flight.
                val id = if (response.requestId != 0) response.requestId else c.pending.keys.singleOrNull()
                val caller = id?.let(c.pending::remove)
                    ?: error("resident worker response id ${response.requestId} matches no request")
                caller.complete(response)
            }
        } catch (e: Throwable) {
            fail(c, e)
        }
    }

    private fun fail(c: Connection, cause: Throwable) {
        // Requests register under `lock` against the current connection, so
        // none can be added to `c` once it is detached here.
        synchronized(lock) { if (connection === c) connection = null }
        c.process.destroyForcibly()
        for (id in c.pending.keys.toList()) c.pending.remove(id)?.completeExceptionally(cause)
    }

    /**
     * Forwards one compile; returns `(exitCode, output)`. [args] are the
     * request arguments, without the command that started the process. Throws
     * when the process died or the stream desynced.
     */
    fun compile(args: List<String>, inputs: List<Input>): Pair<Int, String> {
        val id = nextId.getAndIncrement()
        val request = WorkRequest.newBuilder().addAllArguments(args).addAllInputs(inputs).setRequestId(id).build()
        val response = CompletableFuture<WorkResponse>()
        synchronized(lock) {
            val c = connect()
            c.pending[id] = response
            try {
                request.writeDelimitedTo(c.process.outputStream)
                c.process.outputStream.flush()
                recordSink?.let { request.writeDelimitedTo(it); it.flush() }
            } catch (e: Exception) {
                fail(c, e)
                throw e
            }
        }
        try {
            val r = response.get()
            return r.exitCode to r.output
        } catch (e: ExecutionException) {
            throw e.cause ?: e
        }
    }

    /** Clean shutdown: stdin EOF, then wait for the process to exit. */
    override fun close() {
        val c = synchronized(lock) { connection.also { connection = null } }
        if (c != null) {
            try { c.process.outputStream.close() } catch (_: Exception) {}
            if (!c.process.waitFor(30, TimeUnit.SECONDS)) c.process.destroyForcibly()
        }
        try { recordSink?.close() } catch (_: Exception) {}
    }
}
