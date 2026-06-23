package elide.kotlin.builder

import com.google.devtools.build.lib.worker.WorkerProtocol.WorkRequest
import com.google.devtools.build.lib.worker.WorkerProtocol.WorkResponse
import java.io.ByteArrayInputStream
import java.io.ByteArrayOutputStream
import kotlin.test.Test
import kotlin.test.assertEquals

class WorkerTest {
    @Test fun roundTripsRequestAndResponse() {
        val reqBytes = ByteArrayOutputStream()
        WorkRequest.newBuilder().addArguments("--flagfile=/tmp/f").setRequestId(5)
            .build().writeDelimitedTo(reqBytes)
        val req = Worker.readRequest(ByteArrayInputStream(reqBytes.toByteArray()))!!
        assertEquals(listOf("--flagfile=/tmp/f"), req.argumentsList)
        assertEquals(5, req.requestId)

        val respBytes = ByteArrayOutputStream()
        Worker.writeResponse(respBytes, exitCode = 3, output = "boom", requestId = 5)
        val parsed = WorkResponse.parseDelimitedFrom(ByteArrayInputStream(respBytes.toByteArray()))
        assertEquals(3, parsed.exitCode)
        assertEquals("boom", parsed.output)
        assertEquals(5, parsed.requestId)
    }
}
