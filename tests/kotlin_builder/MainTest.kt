package elide.kotlin.builder

import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertTrue

class MainTest {
    @Test fun splitsConfigFromRest() {
        val (cfg, rest) = Main.splitConfig(listOf(
            "--elide=/bin/elide", "--fallback_builder=/bin/stock", "--flagfile=/tmp/f"))
        assertEquals("/bin/elide", cfg.elide)
        assertEquals("/bin/stock", cfg.fallback)
        assertFalse(cfg.resident, "resident must default off without --resident_worker")
        assertEquals(listOf("--flagfile=/tmp/f"), rest)
    }

    @Test fun residentWorkerFlagOptsIn() {
        val (cfg, rest) = Main.splitConfig(listOf(
            "--elide=/bin/elide", "--resident_worker", "--flagfile=/tmp/f"))
        assertTrue(cfg.resident, "--resident_worker must set Config.resident")
        // The flag is consumed as config, not forwarded as a per-request work arg.
        assertFalse("--resident_worker" in rest, "--resident_worker must not leak into rest")
        assertEquals(listOf("--flagfile=/tmp/f"), rest)
    }
}
