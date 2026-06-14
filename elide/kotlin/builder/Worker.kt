package elide.kotlin.builder

import com.google.devtools.build.lib.worker.WorkerProtocol.WorkRequest
import com.google.devtools.build.lib.worker.WorkerProtocol.WorkResponse
import java.io.InputStream
import java.io.OutputStream

object Worker {
    fun readRequest(s: InputStream): WorkRequest? = WorkRequest.parseDelimitedFrom(s)

    fun writeResponse(o: OutputStream, exitCode: Int, output: String, requestId: Int) {
        WorkResponse.newBuilder()
            .setExitCode(exitCode)
            .setOutput(output)
            .setRequestId(requestId)
            .build()
            .writeDelimitedTo(o)
        o.flush()
    }
}
