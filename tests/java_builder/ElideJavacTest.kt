package elide.java.builder

import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertTrue

class ElideJavacTest {
    @Test fun plainCompile() {
        val req = Request.parse(listOf(
            "--output", "out.jar", "--output_deps_proto", "out.jdeps", "--target_label", "//a:b",
            "--system", "jdk", "--bootclasspath", "boot.jar", "--classpath", "x.jar", "y.jar",
            "--sources", "A.java", "--javacopts", "-source", "25", "-g", "--",
        ))
        assertEquals(
            listOf("elide", "javac", "--jar", "out.jar", "--jdeps", "out.jdeps", "--target-label", "//a:b", "--",
                "-source", "25", "-g", "--system", "jdk", "-classpath", "x.jar:y.jar", "-proc:none", "A.java"),
            ElideJavac.plan(req, "elide", listOf("ep.jar"), emptyList(), ":"),
        )
    }

    @Test fun errorProneBecomesOnePluginArgument() {
        val req = Request.parse(listOf(
            "--output", "out.jar", "--bootclasspath", "boot.jar", "--processorpath", "nullaway.jar", "--sources", "A.java",
            "--javacopts", "-XDcompilePolicy=simple", "-XepDisableAllChecks", "-Xep:NullAway:ERROR",
            "-XepOpt:NullAway:OnlyNullMarked=true", "--",
        ))
        val cmd = ElideJavac.plan(req, "elide", listOf("ep.jar"), listOf("gen/G.java"), ":")
        assertTrue("-XDcompilePolicy=simple" in cmd)
        assertFalse(cmd.any { it.startsWith("-Xep") })
        assertEquals("ep.jar:nullaway.jar", cmd[cmd.indexOf("-processorpath") + 1])
        assertTrue("-Xplugin:ErrorProne -XepDisableAllChecks -Xep:NullAway:ERROR -XepOpt:NullAway:OnlyNullMarked=true" in cmd)
        assertEquals("boot.jar", cmd[cmd.indexOf("-bootclasspath") + 1])
        assertEquals(listOf("A.java", "gen/G.java"), cmd.takeLast(2))
    }

    @Test fun annotationProcessors() {
        val req = Request.parse(listOf(
            "--output", "out.jar", "--processorpath", "proc.jar", "--processors", "p.A", "p.B",
            "--generated_sources_output", "gen.jar", "--sources", "A.java",
        ))
        val cmd = ElideJavac.plan(req, "elide", listOf("ep.jar"), emptyList(), ":", "gensrc")
        assertFalse("-proc:none" in cmd)
        assertEquals("p.A,p.B", cmd[cmd.indexOf("-processor") + 1])
        assertEquals("proc.jar", cmd[cmd.indexOf("-processorpath") + 1])
        assertEquals("gensrc", cmd[cmd.indexOf("-s") + 1])
    }
}
