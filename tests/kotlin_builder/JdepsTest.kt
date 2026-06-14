package elide.kotlin.builder

import com.google.devtools.build.lib.view.proto.Deps
import java.io.File
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertTrue

class JdepsTest {
    @Test fun writesParsableStub() {
        val f = File.createTempFile("jdeps_stub_", ".jdeps")
        Jdeps.writeStub(f.toPath().toString(), ruleLabel = "//pkg:lib")
        val d = Deps.Dependencies.parseFrom(f.readBytes())
        assertEquals("//pkg:lib", d.ruleLabel)
        assertTrue(d.success)
    }
}
