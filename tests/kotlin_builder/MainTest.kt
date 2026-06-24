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

    @Test fun workerRecordFlagCapturesPath() {
        val (cfg, rest) = Main.splitConfig(listOf(
            "--elide=/bin/elide", "--worker_record=/tmp/cap.bin", "--flagfile=/tmp/f"))
        assertEquals("/tmp/cap.bin", cfg.record, "--worker_record=<path> must set Config.record")
        assertEquals(listOf("--flagfile=/tmp/f"), rest, "--worker_record must not leak into rest")
    }

    @Test fun quietPluginRewriteFlagOptsIn() {
        val (cfg, rest) = Main.splitConfig(listOf(
            "--elide=/bin/elide", "--quiet_plugin_rewrite", "--flagfile=/tmp/f"))
        assertTrue(cfg.quietPluginRewrite, "--quiet_plugin_rewrite must set Config.quietPluginRewrite")
        assertFalse("--quiet_plugin_rewrite" in rest, "--quiet_plugin_rewrite must not leak into rest")
    }

    @Test fun quietPluginRewriteDefaultsToWarn() {
        val (cfg, _) = Main.splitConfig(listOf("--elide=/bin/elide", "--flagfile=/tmp/f"))
        assertFalse(cfg.quietPluginRewrite, "warn (quiet off) by default")
    }
}
