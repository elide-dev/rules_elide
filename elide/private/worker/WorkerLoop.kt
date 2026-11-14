package elide.builder.worker

import com.google.devtools.build.lib.worker.WorkerProtocol.WorkRequest
import com.google.devtools.build.lib.worker.WorkerProtocol.WorkResponse
import java.io.InputStream
import java.io.OutputStream
import java.util.concurrent.Executors
import java.util.concurrent.TimeUnit

/** The Bazel persistent-worker request loop shared by the builder shims. */
object WorkerLoop {
    /**
     * Serves requests from [input] until EOF, writing one response per request
     * to [output]. A singleplex request (`request_id` 0) is handled inline; a
     * multiplex request runs on its own thread, so [handle] must be
     * thread-safe. Cancel requests are ignored: the shims do not advertise
     * `supports-worker-cancellation`.
     */
    fun serve(input: InputStream, output: OutputStream, handle: (WorkRequest) -> Pair<Int, String>) {
        val pool = Executors.newCachedThreadPool { r -> Thread(r, "worker-request").apply { isDaemon = true } }
        val write = Any()

        fun respond(request: WorkRequest) {
            val (code, out) = try {
                handle(request)
            } catch (e: Throwable) {
                1 to e.stackTraceToString()
            }
            val response = WorkResponse.newBuilder().setExitCode(code).setOutput(out).setRequestId(request.requestId).build()
            synchronized(write) {
                response.writeDelimitedTo(output)
                output.flush()
            }
        }

        try {
            while (true) {
                val request = WorkRequest.parseDelimitedFrom(input) ?: break
                if (request.cancel) continue
                if (request.requestId == 0) respond(request) else pool.execute { respond(request) }
            }
        } finally {
            pool.shutdown()
            pool.awaitTermination(1, TimeUnit.HOURS)
        }
    }
}
