package elide.builder.worker

import com.google.devtools.build.lib.worker.WorkerProtocol.WorkRequest
import com.google.devtools.build.lib.worker.WorkerProtocol.WorkResponse
import java.io.ByteArrayInputStream
import java.io.ByteArrayOutputStream
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertTrue

class WorkerLoopTest {
    private fun requests(vararg requests: WorkRequest) = ByteArrayOutputStream().also { out ->
        requests.forEach { it.writeDelimitedTo(out) }
    }.let { ByteArrayInputStream(it.toByteArray()) }

    private fun responses(out: ByteArrayOutputStream): List<WorkResponse> {
        val input = ByteArrayInputStream(out.toByteArray())
        return generateSequence { WorkResponse.parseDelimitedFrom(input) }.toList()
    }

    private fun request(id: Int, arg: String) = WorkRequest.newBuilder().setRequestId(id).addArguments(arg).build()

    @Test fun singleplexRequestsAreAnsweredInOrder() {
        val out = ByteArrayOutputStream()
        WorkerLoop.serve(requests(request(0, "a"), request(0, "b")), out) { 3 to it.argumentsList.single() }
        assertEquals(listOf("a", "b"), responses(out).map { it.output })
        assertEquals(listOf(3, 3), responses(out).map { it.exitCode })
    }

    @Test fun multiplexRequestsRunConcurrentlyAndKeepTheirIds() {
        // Each handler waits until both have started, so this only passes when they overlap.
        val started = CountDownLatch(2)
        val out = ByteArrayOutputStream()
        WorkerLoop.serve(requests(request(1, "a"), request(2, "b")), out) {
            started.countDown()
            assertTrue(started.await(30, TimeUnit.SECONDS), "requests did not overlap")
            0 to it.argumentsList.single()
        }
        assertEquals(mapOf(1 to "a", 2 to "b"), responses(out).associate { it.requestId to it.output })
    }

    @Test fun handlerFailuresBecomeErrorResponses() {
        val out = ByteArrayOutputStream()
        WorkerLoop.serve(requests(request(7, "a")), out) { error("boom") }
        val response = responses(out).single()
        assertEquals(1, response.exitCode)
        assertEquals(7, response.requestId)
        assertTrue("boom" in response.output)
    }

    @Test fun cancelRequestsGetNoResponse() {
        val out = ByteArrayOutputStream()
        val cancel = WorkRequest.newBuilder().setRequestId(4).setCancel(true).build()
        WorkerLoop.serve(requests(cancel, request(5, "a")), out) { 0 to "" }
        assertEquals(listOf(5), responses(out).map { it.requestId })
    }
}
