package elide.kotlin.builder

import java.io.File
import java.nio.file.Files
import java.util.zip.ZipEntry
import java.util.zip.ZipOutputStream
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFailsWith
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

    @Test fun abiJarThrowsWhenPluginJarMissing() {
        // Use a non-existent path — findJvmAbiGenJar returns null, plan() must throw immediately.
        val req = CompileRequest(output = "out.jar", abiJar = "abi.jar", sources = listOf("A.kt"))
        val ex = assertFailsWith<IllegalStateException> {
            ElideCompile.plan(req, elidePath = "/nonexistent/bin/elide")
        }
        assertTrue(ex.message?.contains("jvm-abi-gen.jar") == true,
            "expected error message to mention jvm-abi-gen.jar, got: ${ex.message}")
    }

    @Test fun noAbiJarFlagsWhenAbiJarNotRequested() {
        val req = CompileRequest(output = "out.jar", sources = listOf("A.kt"))
        val kotlinc = ElideCompile.plan(req, elidePath = "/bin/elide").first { it.contains("kotlinc") }
        assertTrue(!kotlinc.any { it.startsWith("-Xplugin=") }, "no -Xplugin when abiJar not set")
        assertTrue(!kotlinc.contains("-P"), "no -P when abiJar not set")
    }

    // --- #6: generated sources from --source_jars ---

    @Test fun extraSourcesAddedToKotlincSourceSet() {
        val req = CompileRequest(output = "out.jar", sources = listOf("A.kt"))
        val kotlinc = ElideCompile.plan(req, elidePath = "/bin/elide", extraSources = listOf("gen/pkg/Gen.java"))
            .first { it.contains("kotlinc") }
        assertTrue(kotlinc.contains("A.kt"), "original source present")
        assertTrue(kotlinc.contains("gen/pkg/Gen.java"), "generated source from source_jars must be on the source set")
    }

    @Test fun extractSourceJarsUnpacksKtAndJavaOnly() {
        val jar = File.createTempFile("srcjar", ".jar")
        ZipOutputStream(jar.outputStream()).use { zos ->
            zos.putNextEntry(ZipEntry("pkg/Gen.java")); zos.write("package pkg; class Gen {}".toByteArray()); zos.closeEntry()
            zos.putNextEntry(ZipEntry("pkg/Helper.kt")); zos.write("package pkg\nclass Helper".toByteArray()); zos.closeEntry()
            zos.putNextEntry(ZipEntry("META-INF/MANIFEST.MF")); zos.write("Manifest-Version: 1.0\n".toByteArray()); zos.closeEntry()
        }
        val into = Files.createTempDirectory("extract").toFile()
        try {
            val files = ElideCompile.extractSourceJars(listOf(jar.path), into)
            assertEquals(2, files.size, "only .kt/.java extracted (manifest ignored)")
            assertTrue(files.any { it.endsWith("pkg/Gen.java") && File(it).exists() })
            assertTrue(files.any { it.endsWith("pkg/Helper.kt") && File(it).exists() })
        } finally {
            jar.delete(); into.deleteRecursively()
        }
    }

    @Test fun extractSourceJarsRejectsZipSlip() {
        val jar = File.createTempFile("evil", ".jar")
        ZipOutputStream(jar.outputStream()).use { zos ->
            zos.putNextEntry(ZipEntry("../escape.java")); zos.write("class X {}".toByteArray()); zos.closeEntry()
        }
        val into = Files.createTempDirectory("extract-slip").toFile()
        try {
            assertFailsWith<SecurityException> { ElideCompile.extractSourceJars(listOf(jar.path), into) }
            assertTrue(!File(into.parentFile, "escape.java").exists(), "escaping entry must not be written")
        } finally {
            jar.delete(); into.deleteRecursively()
        }
    }

    // --- #7: run() surfaces captured output instead of swallowing it ---

    @Test fun runReturnsCapturedOutputOnFailure() {
        val (code, out) = ElideCompile.run(listOf(listOf("sh", "-c", "printf 'boom'; exit 3")), File("."))
        assertEquals(3, code)
        assertTrue(out.contains("boom"), "compiler output must be returned (not swallowed to stderr); got: $out")
    }

    @Test fun runReturnsOutputOnSuccess() {
        val (code, out) = ElideCompile.run(listOf(listOf("sh", "-c", "printf 'ok'")), File("."))
        assertEquals(0, code)
        assertTrue(out.contains("ok"))
    }
}
