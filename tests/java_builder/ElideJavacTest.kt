package elide.java.builder

import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertTrue

class ElideJavacTest {
    @Test fun plainCompile() {
        val req = Request.parse(listOf(
            "--output", "out.jar", "--output_deps_proto", "out.jdeps", "--target_label", "@@repo//a:b",
            "--system", "jdk", "--bootclasspath", "boot.jar", "--classpath", "x.jar", "y.jar",
            "--sources", "A.java", "--javacopts", "-source", "25", "-g", "--",
        ))
        assertEquals(
            listOf("elide", "javac", "--jar", "out.jar", "--jdeps", "out.jdeps", "--target-label=@@repo//a:b", "--",
                "-source", "25", "-g", "-classpath", "x.jar:y.jar", "-proc:none", "A.java"),
            ElideJavac.plan(req, "elide", listOf("ep.jar"), emptyList(), ":"),
        )
    }

    @Test fun systemIsForwardedOnlyOnRequest() {
        val req = Request.parse(listOf(
            "--output", "out.jar", "--system", "jdk", "--bootclasspath", "boot.jar", "--sources", "A.java",
        ))
        val default = ElideJavac.plan(req, "elide", listOf("ep.jar"), emptyList(), ":")
        assertFalse("--system" in default)
        assertFalse("-bootclasspath" in default, "the bootclasspath is not a substitute for a withheld --system")
        val forwarded = ElideJavac.plan(req, "elide", listOf("ep.jar"), emptyList(), ":", passSystem = true)
        assertEquals("jdk", forwarded[forwarded.indexOf("--system") + 1])
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

    @Test fun workerArgsDropTheProcessIdentityAndKeepTheSeparator() {
        val req = Request.parse(listOf("--output", "out.jar", "--sources", "A.java"))
        val cmd = ElideJavac.plan(req, "elide", listOf("ep.jar"), emptyList(), ":")
        val args = ElideJavac.workerArgs(cmd)
        assertEquals(cmd.drop(2), args)
        assertEquals(listOf("--jar", "out.jar", "--"), args.take(3))
    }

    @Test fun residentFlagsAreStartupConfig() {
        val (cfg, rest) = Main.splitConfig(listOf("--elide=e", "--resident_worker", "--resident_workers=3", "--output", "o.jar"))
        assertEquals(true, cfg.resident)
        assertEquals(3, cfg.residentWorkers)
        assertEquals(listOf("--output", "o.jar"), rest)
        assertEquals(false, Main.splitConfig(listOf("--elide=e")).first.resident)
    }

    @Test fun stockRequestsCanDisableErrorProne() {
        assertEquals(
            listOf("--output", "o.jar", "--javacopts", "-XepDisableAllChecks", "-g", "--", "--sources", "A.java"),
            Stock.disableErrorProne(listOf("--output", "o.jar", "--javacopts", "-g", "--", "--sources", "A.java")),
        )
        val added = Stock.disableErrorProne(listOf("--output", "o.jar", "--sources", "A.java"))
        assertEquals(listOf("--javacopts", "-XepDisableAllChecks", "--"), added.takeLast(3))
        assertEquals(listOf("-XepDisableAllChecks"), Request.parse(added).javacopts)
        assertEquals(listOf("A.java"), Request.parse(added).sources)
    }

    @Test fun stockErrorProneIsAStartupSetting() {
        assertEquals(false, Main.splitConfig(listOf("--elide=e")).first.stockErrorProne)
        assertEquals(true, Main.splitConfig(listOf("--elide=e", "--stock_error_prone")).first.stockErrorProne)
    }
}
