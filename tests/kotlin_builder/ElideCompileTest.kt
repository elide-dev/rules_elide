package elide.kotlin.builder

import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertTrue

class ElideCompileTest {
    private fun List<String>.hasAll(vararg items: String) = items.all { this.contains(it) }

    @Test fun kotlincCommandHasSeparatorAndOutputs() {
        val req = CompileRequest(
            output = "out.jar", moduleName = "m",
            sources = listOf("A.kt"), classpath = listOf("k.jar"))
        val cmds = ElideCompile.plan(req, elidePath = "/bin/elide")
        val kotlinc = cmds.first { it.contains("kotlinc") }
        assertTrue(kotlinc.hasAll("/bin/elide", "kotlinc", "--", "-d", "out.jar"))
        assertTrue(kotlinc.contains("-classpath"))
        assertTrue(kotlinc.contains("A.kt"))
    }

    @Test fun moduleNameIncluded() {
        val req = CompileRequest(output = "out.jar", moduleName = "mymod", sources = listOf("A.kt"))
        val kotlinc = ElideCompile.plan(req, elidePath = "/bin/elide").first { it.contains("kotlinc") }
        val idx = kotlinc.indexOf("-module-name")
        assertTrue(idx >= 0, "expected -module-name flag")
        assertEquals("mymod", kotlinc[idx + 1])
    }

    @Test fun friendPathsFormattedCorrectly() {
        val req = CompileRequest(
            output = "out.jar",
            sources = listOf("A.kt"),
            friendPaths = listOf("a.jar", "b.jar"))
        val kotlinc = ElideCompile.plan(req, elidePath = "/bin/elide").first { it.contains("kotlinc") }
        assertTrue(kotlinc.any { it.startsWith("-Xfriend-paths=") && it.contains("a.jar") && it.contains("b.jar") })
    }

    @Test fun passthroughFlagsAppended() {
        val req = CompileRequest(
            output = "out.jar",
            sources = listOf("A.kt"),
            passthroughFlags = listOf("-Xjvm-default=all"))
        val kotlinc = ElideCompile.plan(req, elidePath = "/bin/elide").first { it.contains("kotlinc") }
        assertTrue(kotlinc.contains("-Xjvm-default=all"))
    }

    @Test fun srcjarCommandEmittedWhenRequested() {
        val req = CompileRequest(
            output = "out.jar",
            srcjar = "out-src.jar",
            sources = listOf("A.kt", "B.kt"))
        val cmds = ElideCompile.plan(req, elidePath = "/bin/elide")
        val jar = cmds.firstOrNull { it.contains("jar") && !it.contains("kotlinc") }
        assertTrue(jar != null, "expected a jar command for srcjar")
        assertTrue(jar.hasAll("/bin/elide", "jar", "--", "--create", "--file", "out-src.jar"))
        assertTrue(jar.hasAll("A.kt", "B.kt"))
    }

    @Test fun noSrcjarCommandWhenNotRequested() {
        val req = CompileRequest(output = "out.jar", sources = listOf("A.kt"))
        val cmds = ElideCompile.plan(req, elidePath = "/bin/elide")
        assertEquals(1, cmds.size)
    }

    @Test fun emptyClasspathOmitsFlag() {
        val req = CompileRequest(output = "out.jar", sources = listOf("A.kt"), classpath = emptyList())
        val kotlinc = ElideCompile.plan(req, elidePath = "/bin/elide").first { it.contains("kotlinc") }
        assertTrue(!kotlinc.contains("-classpath"), "classpath flag should be absent when cp is empty")
    }

    // --- ABI jar (jvm-abi-gen) tests ---

    @Test fun abiJarInjectsXpluginWhenPluginJarFound() {
        // Stub elidePath to point at the real Elide binary so findJvmAbiGenJar can locate
        // lib/resources/kotlin/<ver>/lib/jvm-abi-gen.jar from the distribution root.
        val elideBin = System.getenv("ELIDE_BINARY_PATH")
            ?: return  // skip if not running under Bazel with the toolchain present
        val req = CompileRequest(output = "out.jar", abiJar = "abi.jar", sources = listOf("A.kt"))
        val kotlinc = ElideCompile.plan(req, elidePath = elideBin).first { it.contains("kotlinc") }
        assertTrue(kotlinc.any { it.startsWith("-Xplugin=") && it.contains("jvm-abi-gen") },
            "expected -Xplugin=...jvm-abi-gen.jar in kotlinc argv")
        val pIdx = kotlinc.indexOf("-P")
        assertTrue(pIdx >= 0, "expected -P flag")
        assertTrue(kotlinc[pIdx + 1].contains("org.jetbrains.kotlin.jvm.abi") &&
            kotlinc[pIdx + 1].contains("outputDir=abi.jar"),
            "expected plugin option -P plugin:org.jetbrains.kotlin.jvm.abi:outputDir=abi.jar")
    }

    @Test fun abiJarSkippedGracefullyWhenPluginJarMissing() {
        // Use a non-existent path — findJvmAbiGenJar returns null, flags are omitted silently.
        val req = CompileRequest(output = "out.jar", abiJar = "abi.jar", sources = listOf("A.kt"))
        val kotlinc = ElideCompile.plan(req, elidePath = "/nonexistent/bin/elide").first { it.contains("kotlinc") }
        assertTrue(!kotlinc.any { it.startsWith("-Xplugin=") },
            "no -Xplugin flag when plugin jar cannot be found")
        assertTrue(!kotlinc.contains("-P"),
            "no -P flag when plugin jar cannot be found")
    }

    @Test fun noAbiJarFlagsWhenAbiJarNotRequested() {
        val req = CompileRequest(output = "out.jar", sources = listOf("A.kt"))
        val kotlinc = ElideCompile.plan(req, elidePath = "/bin/elide").first { it.contains("kotlinc") }
        assertTrue(!kotlinc.any { it.startsWith("-Xplugin=") }, "no -Xplugin when abiJar not set")
        assertTrue(!kotlinc.contains("-P"), "no -P when abiJar not set")
    }
}
