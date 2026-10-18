package elide.kotlin.builder

import java.io.File
import java.nio.file.Files
import java.util.zip.ZipFile
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertTrue

class KspTest {
    // rules_kotlin 2.4's KotlinKsp2 flagfile (one token per line).
    private val tokens = listOf(
        "--module_name", "app",
        "--sources", "src/App.kt", "src/Util.java",
        "--generated_sources_output", "out/app-ksp-gensrc.jar",
        "--generated_classes_output", "out/app-ksp-genclasses.jar",
        "--jvm_target", "17",
        "--language_version", "2.1",
        "--api_version", "2.1",
        "--jdk_home", "external/jdk",
        "--libraries", "lib/a.jar", "lib/b.jar",
        "--processor_classpath", "external/rules_kotlin+/src/main/kotlin/ksp2_invoker.jar",
        "maven/symbol-processing-api.jar", "maven/moshi-kotlin-codegen.jar",
        "--ksp_options", "moshi.generated=javax.annotation.Generated",
    )

    @Test fun recognizesKsp2Actions() {
        assertTrue(Ksp.isKsp(Flagfile.parse(tokens)))
        assertFalse(Ksp.isKsp(Flagfile.parse(listOf("--output", "a.jar", "--sources", "A.kt"))))
    }

    @Test fun plansElideKotlincWithJarOutputs() {
        val sep = File.pathSeparator
        assertEquals(
            listOf(
                "elide", "kotlinc",
                "--ksp-sources", "out/app-ksp-gensrc.jar",
                "--ksp-classes", "out/app-ksp-genclasses.jar",
                "--processorpath", "maven/symbol-processing-api.jar${sep}maven/moshi-kotlin-codegen.jar",
                "--processor-option", "moshi.generated=javax.annotation.Generated",
                "--",
                "-module-name", "app",
                "-jvm-target", "17",
                "-language-version", "2.1",
                "-api-version", "2.1",
                "-cp", "lib/a.jar${sep}lib/b.jar",
                "src/App.kt", "src/Util.java", "gen/G.kt",
            ),
            Ksp.plan(Flagfile.parse(tokens), "elide", listOf("gen/G.kt")),
        )
    }

    @Test fun writesEmptyJarsWithoutSources() {
        val dir = Files.createTempDirectory("ksp-test").toFile()
        try {
            val srcs = File(dir, "gensrc.jar"); val classes = File(dir, "genclasses.jar")
            val req = Flagfile.parse(listOf(
                "--module_name", "empty",
                "--generated_sources_output", srcs.path,
                "--generated_classes_output", classes.path,
            ))
            // No sources: nothing to process, so no Elide call is made.
            val (code, _) = Ksp.handle(Main.Config(elide = "/nonexistent/elide", fallback = ""), req, "unused", dir)
            assertEquals(0, code)
            listOf(srcs, classes).forEach { ZipFile(it).use { z -> assertEquals(0, z.size()) } }
        } finally {
            dir.deleteRecursively()
        }
    }
}
