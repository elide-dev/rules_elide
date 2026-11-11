package elide.java.builder

import java.nio.file.Files
import kotlin.test.Test
import kotlin.test.assertEquals

class RouterTest {
    private val plugins = Capabilities(annotationProcessing = true, javacPlugins = true)
    private val noPlugins = Capabilities(annotationProcessing = true, javacPlugins = false)

    private fun req(vararg extra: String) = Request.parse(listOf("--output", "a.jar", "--sources", "A.java") + extra)

    @Test fun plainCompileUsesElide() {
        assertEquals(Route.ELIDE, Router.decide(req("--javacopts", "-g", "--"), noPlugins).route)
    }

    @Test fun errorProneWaitsForJavacPlugins() {
        val ep = req("--javacopts", "-XepDisableAllChecks", "--")
        assertEquals(Route.STOCK, Router.decide(ep, noPlugins).route)
        assertEquals(Route.ELIDE, Router.decide(ep, plugins).route)
        val nullaway = req("--processorpath", "nullaway.jar")
        assertEquals(Route.STOCK, Router.decide(nullaway, noPlugins).route)
        assertEquals(Route.ELIDE, Router.decide(nullaway, plugins).route)
    }

    @Test fun processorsAndUnknownFlagsUseStock() {
        assertEquals(Route.STOCK, Router.decide(req("--processors", "p.P", "--generated_sources_output", "g.jar"), plugins).route)
        assertEquals(Route.STOCK, Router.decide(req("--reduce_classpath_mode", "JAVABUILDER_REDUCED"), plugins).route)
        assertEquals(Route.ELIDE, Router.decide(req("--reduce_classpath_mode", "BAZEL_REDUCED"), plugins).route)
        assertEquals(Route.STOCK, Router.decide(req("--injecting_rule_kind", "x", "--unknown_flag"), plugins).route)
        assertEquals(Route.STOCK, Router.decide(req("--javacopts", "-h", "dir", "--"), plugins).route)
        assertEquals(Route.STOCK, Router.decide(req("--javacopts", "-J-Xmx1g", "--"), plugins).route)
    }

    @Test fun nativeMethodsUseStock() {
        val dir = Files.createTempDirectory("router")
        val native = dir.resolve("N.java").also { Files.writeString(it, "class N { native int f(); }") }
        val plain = dir.resolve("P.java").also { Files.writeString(it, "class P { int nativeCount() { return 0; } }") }
        val base = listOf("--output", "a.jar", "--native_header_output", "h.jar", "--sources")
        assertEquals(Route.STOCK, Router.decide(Request.parse(base + native.toString()), plugins).route)
        assertEquals(Route.ELIDE, Router.decide(Request.parse(base + plain.toString()), plugins).route)
    }

    @Test fun parsesCapabilities() {
        val caps = Capabilities.parse("""{"version": 1, "javaAnnotationProcessing": true, "javacPlugins": false}""")
        assertEquals(Capabilities(annotationProcessing = true, javacPlugins = false), caps)
        assertEquals(true, Capabilities.parse("""{"javacPlugins":true}""").javacPlugins)
    }
}
