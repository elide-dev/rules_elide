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

    @Test fun nativeAbiAndJdepsDoNotNeedPluginDiscovery() {
        val req = CompileRequest(output = "out.jar", abiJar = "abi.jar", jdeps = "out.jdeps",
            targetLabel = "//app:lib", sources = listOf("A.kt"))
        val kt = ElideCompile.plan(req, "/nonexistent/elide").first()
        assertTrue(kt.indexOf("--emit-abi") > kt.indexOf("--"))
        assertEquals("abi.jar", kt[kt.indexOf("--emit-abi") + 1])
        assertEquals("out.jdeps", kt[kt.indexOf("--jdeps") + 1])
        assertTrue("--target-label=//app:lib" in kt)
        assertTrue(kt.none { it.contains("jvm-abi-gen") })
    }

    @Test fun legacyAbiStillRequiresPlugin() {
        assertFailsWith<IllegalStateException> {
            ElideCompile.plan(CompileRequest(output = "out.jar", abiJar = "abi.jar"),
                "/nonexistent/elide", nativeTools = false)
        }
    }

    @Test fun kaptProducesAllDeclaredOutputsWithoutAFullCompile() {
        val req = CompileRequest(kaptSources = "sources.jar", kaptClasses = "classes.jar",
            kaptStubs = "stubs.jar", processors = listOf("example.Processor"),
            processorPath = listOf("processor.jar"), processorOptions = listOf("name=Hello"), sources = listOf("A.kt"))
        val kt = ElideCompile.plan(req, "/bin/elide").single()
        assertTrue(kt.hasAll("--kapt-sources", "sources.jar", "--kapt-classes", "classes.jar", "--kapt-stubs", "stubs.jar"))
        assertTrue(kt.hasAll("--processor-option", "name=Hello", "--processors", "example.Processor"))
        assertTrue("-d" !in kt)
    }

    @Test fun kspProducesGeneratedSourcesAndResources() {
        val req = Flagfile.parse(listOf("--generated_sources_output", "sources.jar",
            "--generated_classes_output", "classes.jar", "--processor_classpath", "processor.jar",
            "--libraries", "dep.jar", "--ksp_options", "key=value", "--sources", "A.kt",
            "--language_version", "2.4", "--jvm_target", "21"))
        val kt = ElideCompile.plan(req, "/bin/elide").single()
        assertTrue(kt.hasAll("--ksp-sources", "sources.jar", "--ksp-classes", "classes.jar"))
        assertTrue(kt.hasAll("--processorpath", "processor.jar", "--processor-option", "key=value"))
        assertTrue(kt.hasAll("-classpath", "dep.jar", "-language-version", "2.4", "-jvm-target", "21"))
    }

    @Test fun noAbiJarFlagsWhenAbiJarNotRequested() {
        val req = CompileRequest(output = "out.jar", sources = listOf("A.kt"))
        val kotlinc = ElideCompile.plan(req, elidePath = "/bin/elide").first { it.contains("kotlinc") }
        assertTrue(!kotlinc.any { it.startsWith("-Xplugin=") }, "no -Xplugin when abiJar not set")
        assertTrue(!kotlinc.contains("-P"), "no -P when abiJar not set")
    }

    // --- #8: compiler-plugin options + Kotlin api/language version ---

    @Test fun compilerPluginOptionsForwardedAsDashP() {
        val opt = "dev.zacsweers.metro.compiler:interop-include-jakarta-annotations=true"
        val req = CompileRequest(
            output = "out.jar", sources = listOf("A.kt"),
            compilerPluginClasspath = listOf("/m/metro.jar"),
            compilerPluginOptions = listOf(opt))
        val kt = ElideCompile.plan(req, elidePath = "/bin/elide").first { it.contains("kotlinc") }
        assertTrue(kt.contains("-Xplugin=/m/metro.jar"), "plugin jar must load via -Xplugin")
        assertTrue(kt.contains("plugin:$opt"), "plugin option must be forwarded as -P plugin:<id>:<k>=<v>")
    }

    @Test fun compilerPluginNotDoubleLoadedWhenAlreadyInPassthrough() {
        val req = CompileRequest(
            output = "out.jar", sources = listOf("A.kt"),
            compilerPluginClasspath = listOf("/m/metro.jar"),
            passthroughFlags = listOf("-Xplugin=/m/metro.jar"))
        val kt = ElideCompile.plan(req, elidePath = "/bin/elide").first { it.contains("kotlinc") }
        assertEquals(1, kt.count { it == "-Xplugin=/m/metro.jar" }, "must not double-load the plugin")
    }

    @Test fun builtinPluginXpluginRewrittenToFlag() {
        // A -Xplugin jar duplicating an Elide builtin (serialization) is dropped
        // and the version-pinned builtin is enabled via `--plugins=` instead.
        val req = CompileRequest(
            output = "out.jar", sources = listOf("A.kt"),
            compilerPluginClasspath = listOf("/ext/lib/kotlinx-serialization-compiler-plugin.jar"))
        val kt = ElideCompile.plan(req, elidePath = "/bin/elide").first { it.contains("kotlinc") }
        assertTrue(
            kt.none { it.startsWith("-Xplugin=") && it.contains("kotlinx-serialization") },
            "serialization -Xplugin jar must be dropped",
        )
        assertTrue(kt.contains("--plugins=serialization"), "must enable the serialization builtin")
        assertTrue(
            kt.indexOf("--plugins=serialization") < kt.indexOf("--"),
            "--plugins is an elide option; must precede the `--` separator",
        )
    }

    @Test fun builtinPluginRewrittenAlsoFromPassthrough() {
        val req = CompileRequest(
            output = "out.jar", sources = listOf("A.kt"),
            passthroughFlags = listOf("-Xplugin=/x/kotlinx-serialization-compiler-plugin.jar"))
        val kt = ElideCompile.plan(req, elidePath = "/bin/elide").first { it.contains("kotlinc") }
        assertTrue(kt.none { it.contains("kotlinx-serialization") }, "passthrough serialization -Xplugin dropped")
        assertTrue(kt.contains("--plugins=serialization"))
    }

    @Test fun nonBuiltinXpluginNotRewritten() {
        val req = CompileRequest(
            output = "out.jar", sources = listOf("A.kt"),
            compilerPluginClasspath = listOf("/x/dagger-compiler.jar"))
        val kt = ElideCompile.plan(req, elidePath = "/bin/elide").first { it.contains("kotlinc") }
        assertTrue(kt.contains("-Xplugin=/x/dagger-compiler.jar"), "non-builtin plugin must NOT be stripped")
        assertTrue(kt.none { it.startsWith("--plugins=") }, "no builtin enabled for a non-builtin jar")
    }

    @Test fun kotlinApiAndLanguageVersionForwarded() {
        val req = CompileRequest(output = "out.jar", sources = listOf("A.kt"), apiVersion = "2.1", languageVersion = "2.1")
        val kt = ElideCompile.plan(req, elidePath = "/bin/elide").first { it.contains("kotlinc") }
        val a = kt.indexOf("-api-version"); assertTrue(a >= 0 && kt[a + 1] == "2.1", "-api-version 2.1 expected")
        val l = kt.indexOf("-language-version"); assertTrue(l >= 0 && kt[l + 1] == "2.1", "-language-version 2.1 expected")
    }

    // --- jdeps: --report-used-deps is an elide option, before the `--` separator ---

    @Test fun usedDepsReportFlagPrecedesSeparator() {
        val req = CompileRequest(output = "out.jar", sources = listOf("A.kt"))
        val kt = ElideCompile.plan(req, elidePath = "/bin/elide", usedDepsReport = "/tmp/used.txt")
            .first { it.contains("kotlinc") }
        val r = kt.indexOf("--report-used-deps")
        val sep = kt.indexOf("--")
        assertTrue(r in 0 until sep, "--report-used-deps must precede the -- separator (it is an Elide option)")
        assertEquals("/tmp/used.txt", kt[r + 1])
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

    @Test fun payloadPluginsBecomeXpluginAndOptions() {
        val allOpen = PayloadPlugin("org.jetbrains.kotlin.allopen", listOf("x/kotlin-allopen-compiler-plugin-embeddable.jar"),
            listOf(mapOf("key" to "preset", "value" to "spring")), listOf("PLUGIN_PHASE_COMPILE"))
        val serialization = PayloadPlugin("org.jetbrains.kotlinx.serialization",
            listOf("x/kotlin-serialization-compiler-plugin-embeddable.jar"), emptyList(), listOf("PLUGIN_PHASE_COMPILE"))
        val stubsOnly = PayloadPlugin("stubs.only", listOf("x/stubs.jar"), emptyList(), listOf("PLUGIN_PHASE_STUBS"))
        val req = CompileRequest(output = "out.jar", sources = listOf("A.kt"), payloadPlugins = listOf(allOpen, serialization, stubsOnly))
        val kt = ElideCompile.plan(req, elidePath = "/bin/elide", externalPlugins = true).first { it.contains("kotlinc") }
        assertTrue(kt.hasAll("-Xplugin=x/kotlin-allopen-compiler-plugin-embeddable.jar", "-P", "plugin:org.jetbrains.kotlin.allopen:preset=spring"))
        assertTrue("--plugins=serialization" in kt)
        assertTrue("-Xplugin=x/kotlin-serialization-compiler-plugin-embeddable.jar" !in kt)
        assertTrue("-Xplugin=x/stubs.jar" !in kt)
        val withoutCapability = ElideCompile.plan(req, elidePath = "/bin/elide").first { it.contains("kotlinc") }
        assertTrue(withoutCapability.none { it.startsWith("-Xplugin=x/kotlin-allopen") })
    }
}
