package elide.kotlin.builder

import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertTrue

class FlagfileTest {
    @Test fun parsesScalarAndRepeatedFlags() {
        val req = Flagfile.parse(listOf(
            "--output", "out.jar",
            "--kotlin_module_name", "greeter",
            "--sources", "A.kt", "B.kt",
            "--classpath", "a.jar", "b.jar",
            "--strict_kotlin_deps", "off",
        ))
        assertEquals("out.jar", req.output)
        assertEquals("greeter", req.moduleName)
        assertEquals(listOf("A.kt", "B.kt"), req.sources)
        assertEquals(listOf("a.jar", "b.jar"), req.classpath)
        assertEquals("off", req.strictKotlinDeps)
        assertTrue(req.processors.isEmpty())
    }

    @Test fun capturesProcessorsForKapt() {
        val req = Flagfile.parse(listOf("--processors", "com.example.P", "--processorpath", "p.jar"))
        assertEquals(listOf("com.example.P"), req.processors)
        assertEquals(listOf("p.jar"), req.processorPath)
    }
}
