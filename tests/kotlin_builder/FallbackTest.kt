package elide.kotlin.builder

import kotlin.test.Test
import kotlin.test.assertEquals

class FallbackTest {
    @Test fun passesFlagfileVerbatim() {
        assertEquals(
            listOf("/bin/stock", "--flagfile=/tmp/f"),
            Fallback.command(stockBuilder = "/bin/stock", flagfile = "/tmp/f"),
        )
    }
}
