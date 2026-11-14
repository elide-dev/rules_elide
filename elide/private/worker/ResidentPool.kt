package elide.builder.worker

import com.google.devtools.build.lib.worker.WorkerProtocol.Input
import java.util.concurrent.locks.ReentrantLock
import kotlin.concurrent.withLock

/**
 * Up to [size] resident Elide processes, each serving one compile at a time.
 *
 * Elide compiles the requests of one process serially, so a shim that receives
 * concurrent (multiplex) requests needs several processes to compile in
 * parallel. Processes start on demand; the most recently used idle one is
 * reused first, so a serial build keeps a single warm process.
 */
class ResidentPool(private val size: Int, private val create: () -> ResidentWorker) : AutoCloseable {
    init {
        require(size > 0) { "resident pool size must be positive" }
    }

    private val all = ArrayList<ResidentWorker>()
    private val idle = ArrayDeque<ResidentWorker>()
    private val lock = ReentrantLock()
    private val released = lock.newCondition()

    private fun acquire(): ResidentWorker = lock.withLock {
        while (true) {
            idle.removeLastOrNull()?.let { return it }
            if (all.size < size) return create().also(all::add)
            released.await()
        }
        @Suppress("UNREACHABLE_CODE")
        error("unreachable")
    }

    /** Forwards one compile to an idle process, waiting for one when all are busy. */
    fun compile(args: List<String>, inputs: List<Input>): Pair<Int, String> {
        val worker = acquire()
        try {
            return worker.compile(args, inputs)
        } finally {
            lock.withLock {
                idle.addLast(worker)
                released.signal()
            }
        }
    }

    override fun close() {
        val workers = lock.withLock { all.toList().also { all.clear(); idle.clear() } }
        workers.forEach(ResidentWorker::close)
    }

    companion object {
        /** Pool size when the toolchain does not set one. */
        fun defaultSize(): Int = Runtime.getRuntime().availableProcessors().coerceIn(1, DEFAULT_MAX)

        const val DEFAULT_MAX = 8
    }
}
