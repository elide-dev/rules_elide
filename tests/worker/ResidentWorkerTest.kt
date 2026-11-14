package elide.builder.worker

import com.google.devtools.build.lib.worker.WorkerProtocol.WorkRequest
import com.google.devtools.build.lib.worker.WorkerProtocol.WorkResponse
import java.io.ByteArrayOutputStream
import java.io.InputStream
import java.io.OutputStream
import java.io.PipedInputStream
import java.io.PipedOutputStream
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit
import kotlin.concurrent.thread
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFailsWith
import kotlin.test.assertTrue

/** An in-process stand-in for a persistent-worker subprocess, driven by [serve]. */
internal class FakeWorker(serve: (InputStream, OutputStream) -> Unit) : Process() {
    private val stdin = PipedOutputStream()
    private val stdout = PipedInputStream()
    private val exited = CountDownLatch(1)

    init {
        val requests = PipedInputStream(stdin, 1 shl 16)
        val responses = PipedOutputStream(stdout)
        thread(isDaemon = true) {
            try {
                serve(requests, responses)
            } catch (_: Exception) {
            } finally {
                try { responses.close() } catch (_: Exception) {}
                exited.countDown()
            }
        }
    }

    override fun getOutputStream(): OutputStream = stdin
    override fun getInputStream(): InputStream = stdout
    override fun getErrorStream(): InputStream = InputStream.nullInputStream()
    override fun waitFor(): Int { exited.await(); return 0 }
    override fun waitFor(timeout: Long, unit: TimeUnit): Boolean = exited.await(timeout, unit)
    override fun exitValue(): Int = if (exited.count == 0L) 0 else throw IllegalThreadStateException()
    override fun isAlive(): Boolean = exited.count != 0L
    override fun destroy() { try { stdin.close() } catch (_: Exception) {} }
    override fun destroyForcibly(): Process { destroy(); return this }
}

internal fun reply(request: WorkRequest, out: OutputStream, id: Int = request.requestId) {
    WorkResponse.newBuilder().setRequestId(id).setExitCode(request.argumentsCount).setOutput(request.argumentsList.joinToString(","))
        .build().writeDelimitedTo(out)
    out.flush()
}

class ResidentWorkerTest {
    @Test fun forwardsArgsAndReusesOneProcess() {
        var starts = 0
        val resident = ResidentWorker({
            starts++
            FakeWorker { i, o -> while (true) reply(WorkRequest.parseDelimitedFrom(i) ?: break, o) }
        })
        assertEquals(2 to "a,b", resident.compile(listOf("a", "b"), emptyList()))
        assertEquals(1 to "c", resident.compile(listOf("c"), emptyList()))
        assertEquals(1, starts)
        resident.close()
    }

    @Test fun matchesConcurrentRequestsAnsweredOutOfOrder() {
        // The fake answers only once it holds both requests, and answers the second one first.
        val resident = ResidentWorker({
            FakeWorker { i, o ->
                val first = WorkRequest.parseDelimitedFrom(i)
                val second = WorkRequest.parseDelimitedFrom(i)
                reply(second, o)
                reply(first, o)
            }
        })
        val results = arrayOfNulls<Pair<Int, String>>(2)
        val callers = listOf("x", "y").mapIndexed { n, arg -> thread { results[n] = resident.compile(listOf(arg), emptyList()) } }
        callers.forEach { it.join(30_000) }
        assertEquals(listOf(1 to "x", 1 to "y"), results.toList())
        resident.close()
    }

    @Test fun acceptsAnUnsetResponseIdForASingleRequest() {
        val resident = ResidentWorker({ FakeWorker { i, o -> reply(WorkRequest.parseDelimitedFrom(i), o, id = 0) } })
        assertEquals(1 to "a", resident.compile(listOf("a"), emptyList()))
        resident.close()
    }

    @Test fun aDeadProcessFailsTheRequestAndTheNextOneRestarts() {
        var starts = 0
        val resident = ResidentWorker({
            starts++
            if (starts == 1) FakeWorker { i, _ -> WorkRequest.parseDelimitedFrom(i) } // exits without answering
            else FakeWorker { i, o -> while (true) reply(WorkRequest.parseDelimitedFrom(i) ?: break, o) }
        })
        assertFailsWith<IllegalStateException> { resident.compile(listOf("a"), emptyList()) }
        assertEquals(1 to "b", resident.compile(listOf("b"), emptyList()))
        assertEquals(2, starts)
        resident.close()
    }

    @Test fun aMismatchedResponseIdFailsTheRequest() {
        val resident = ResidentWorker({ FakeWorker { i, o -> reply(WorkRequest.parseDelimitedFrom(i), o, id = 999) } })
        assertFailsWith<IllegalStateException> { resident.compile(listOf("a"), emptyList()) }
        resident.close()
    }

    @Test fun recordsForwardedRequests() {
        val record = ByteArrayOutputStream()
        val resident = ResidentWorker({ FakeWorker { i, o -> reply(WorkRequest.parseDelimitedFrom(i), o) } }, record)
        resident.compile(listOf("a"), emptyList())
        val recorded = WorkRequest.parseDelimitedFrom(record.toByteArray().inputStream())
        assertEquals(listOf("a"), recorded.argumentsList)
        assertTrue(recorded.requestId != 0)
        resident.close()
    }
}
