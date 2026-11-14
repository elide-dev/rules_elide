package elide.java.builder

import java.nio.file.Files
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertNull
import kotlin.test.assertTrue

class RequestTest {
    private val args = listOf(
        "--output", "out/lib.jar", "--native_header_output", "out/lib-native-header.jar",
        "--output_manifest_proto", "out/lib.jar_manifest_proto", "--compress_jar", "--output_deps_proto", "out/lib.jdeps",
        "--bootclasspath", "platformclasspath.jar", "--system", "external/jdk",
        "--processorpath", "nullaway.jar", "dataflow.jar",
        "--sources", "A.java", "B.java",
        "--javacopts", "-source", "25", "-XepDisableAllChecks", "-Xep:NullAway:ERROR", "--",
        "--target_label", "@@repo//pkg:lib", "--strict_java_deps", "ERROR", "--experimental_fix_deps_tool", "add_dep",
        "--direct_dependencies", "dep-ijar.jar", "--classpath", "dep-ijar.jar", "transitive-ijar.jar",
    )

    @Test fun parsesJavaBuilderFlags() {
        val req = Request.parse(args)
        assertEquals("out/lib.jar", req.output)
        assertEquals("out/lib.jdeps", req.depsProto)
        assertEquals("external/jdk", req.system)
        assertEquals(listOf("A.java", "B.java"), req.sources)
        assertEquals(listOf("nullaway.jar", "dataflow.jar"), req.processorpath)
        assertEquals(listOf("-source", "25", "-XepDisableAllChecks", "-Xep:NullAway:ERROR"), req.javacopts)
        assertEquals(listOf("dep-ijar.jar"), req.directDependencies)
        assertEquals(listOf("dep-ijar.jar", "transitive-ijar.jar"), req.classpath)
        assertEquals("@@repo//pkg:lib", req.targetLabel)
        assertEquals("ERROR", req.strictJavaDeps)
        assertTrue(req.unknown.isEmpty())
        assertNull(req.generatedSourcesOutput)
    }

    @Test fun expandsParamFilesButNotLabels() {
        val params = Files.createTempFile("javabuilder", ".params")
        Files.write(params, args)
        val req = Request.parse(listOf("@$params"))
        assertEquals("@@repo//pkg:lib", req.targetLabel)
        // Pre-expanded worker arguments (BuildBuddy) keep `@@` labels and `@` values that are not files.
        assertEquals("@@repo//pkg:lib", Request.parse(args).targetLabel)
        assertEquals(listOf("@not-a-file"), Request.expand(listOf("@not-a-file")))
    }

    @Test fun unquotesShellQuotedParamLines() {
        assertEquals("-XepExcludedPaths:.*/a b/.*", Request.unquote("'-XepExcludedPaths:.*/a b/.*'"))
        assertEquals("it's", Request.unquote("'it'\\''s'"))
        assertEquals("plain", Request.unquote("plain"))
    }

    @Test fun recordsUnknownFlags() {
        val req = Request.parse(listOf("--output", "a.jar", "--reduce_classpath_mode", "BAZEL_REDUCED", "--frobnicate"))
        assertEquals("BAZEL_REDUCED", req.reduceClasspathMode)
        assertEquals(listOf("--frobnicate"), req.unknown)
    }
}
