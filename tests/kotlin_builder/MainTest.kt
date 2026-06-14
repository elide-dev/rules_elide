package elide.kotlin.builder

import kotlin.test.Test
import kotlin.test.assertEquals

class MainTest {
    @Test fun splitsConfigFromRest() {
        val (cfg, rest) = Main.splitConfig(listOf(
            "--elide=/bin/elide", "--fallback_builder=/bin/stock", "--flagfile=/tmp/f"))
        assertEquals("/bin/elide", cfg.elide)
        assertEquals("/bin/stock", cfg.fallback)
        assertEquals(listOf("--flagfile=/tmp/f"), rest)
    }
}
