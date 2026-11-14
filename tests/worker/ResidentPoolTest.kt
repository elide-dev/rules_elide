package elide.builder.worker

import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicInteger
import kotlin.concurrent.thread
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertTrue

class ResidentPoolTest {
    /** A worker whose single compile blocks until [release] opens. */
    private fun blocking(started: CountDownLatch, release: CountDownLatch) = ResidentWorker({
        FakeWorker { i, o ->
            while (true) {
                val request = com.google.devtools.build.lib.worker.WorkerProtocol.WorkRequest.parseDelimitedFrom(i) ?: break
                started.countDown()
                release.await(30, TimeUnit.SECONDS)
                reply(request, o)
            }
        }
    })

    @Test fun serialCompilesReuseOneProcess() {
        val created = AtomicInteger()
        val pool = ResidentPool(4) { created.incrementAndGet(); blocking(CountDownLatch(1), CountDownLatch(0)) }
        repeat(3) { assertEquals(1 to "a", pool.compile(listOf("a"), emptyList())) }
        assertEquals(1, created.get())
        pool.close()
    }

    @Test fun concurrentCompilesUseSeparateProcessesUpToTheLimit() {
        val created = AtomicInteger()
        val started = CountDownLatch(2)
        val release = CountDownLatch(1)
        val pool = ResidentPool(2) { created.incrementAndGet(); blocking(started, release) }
        val done = AtomicInteger()
        val callers = (1..3).map { thread { pool.compile(listOf("a"), emptyList()); done.incrementAndGet() } }
        // Two compiles overlap on two processes; the third waits for one of them.
        assertTrue(started.await(30, TimeUnit.SECONDS), "two compiles did not overlap")
        assertEquals(0, done.get())
        release.countDown()
        callers.forEach { it.join(30_000) }
        assertEquals(3, done.get())
        assertEquals(2, created.get())
        pool.close()
    }
}
