package elide.kotlin.builder

import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertTrue

// Real compiler-plugin jar basenames (as rules_kotlin / the Kotlin dist ship them).
private const val SERIALIZATION_JAR = "kotlinx-serialization-compiler-plugin.jar"
private const val POWER_ASSERT_JAR = "kotlin-power-assert-compiler-plugin.jar"
private const val ATOMICFU_JAR = "atomicfu-compiler-plugin.jar"
private const val METRO_JAR = "metro-compiler.jar"

class BuiltinPluginsTest {
    @Test fun detectsSerializationFromClasspath() {
        val r = BuiltinPlugins.detect(CompileRequest(compilerPluginClasspath = listOf("/ext/lib/" + SERIALIZATION_JAR)))
        assertEquals(1, r.size)
        assertEquals("serialization", r[0].builtin)
        assertEquals(listOf("serialization"), BuiltinPlugins.builtinNames(r))
    }

    @Test fun detectsAllFourBuiltins() {
        val r = BuiltinPlugins.detect(CompileRequest(compilerPluginClasspath = listOf(
            "/l/" + SERIALIZATION_JAR, "/l/" + POWER_ASSERT_JAR, "/l/" + ATOMICFU_JAR, "/l/" + METRO_JAR,
        )))
        assertEquals(
            listOf("serialization", "power-assert", "atomicfu", "metro").sorted(),
            BuiltinPlugins.builtinNames(r).sorted(),
        )
    }

    @Test fun matchesKotlinPrefixVariantToo() {
        // The dist ships `kotlin-serialization-compiler-plugin.jar`; the elide
        // warning reports `kotlinx-...`. Both must map (substring omits the prefix).
        val r = BuiltinPlugins.detect(CompileRequest(
            compilerPluginClasspath = listOf("/l/kotlin-serialization-compiler-plugin.jar")))
        assertEquals(listOf("serialization"), BuiltinPlugins.builtinNames(r))
    }

    @Test fun detectsFromPassthrough() {
        val r = BuiltinPlugins.detect(CompileRequest(passthroughFlags = listOf("-Xplugin=/x/" + SERIALIZATION_JAR)))
        assertEquals(1, r.size)
        assertEquals("serialization", r[0].builtin)
    }

    @Test fun dedupesSameJarAcrossSources() {
        val r = BuiltinPlugins.detect(CompileRequest(
            compilerPluginClasspath = listOf("/x/" + SERIALIZATION_JAR),
            passthroughFlags = listOf("-Xplugin=/x/" + SERIALIZATION_JAR),
        ))
        assertEquals(1, r.size, "same jar in classpath and passthrough must collapse to one rewrite")
    }

    @Test fun ignoresNonBuiltinJars() {
        // A genuinely unrelated plugin jar (and the metro *runtime*, not its compiler).
        val r = BuiltinPlugins.detect(CompileRequest(compilerPluginClasspath = listOf(
            "/x/dagger-compiler.jar", "/x/metro-runtime.jar",
        )))
        assertTrue(r.isEmpty())
    }

    @Test fun isRewrittenXpluginMatchesOnlyBuiltins() {
        assertTrue(BuiltinPlugins.isRewrittenXplugin("-Xplugin=/x/" + SERIALIZATION_JAR))
        assertTrue(BuiltinPlugins.isRewrittenXplugin("-Xplugin=/x/" + METRO_JAR))
        assertFalse(BuiltinPlugins.isRewrittenXplugin("-Xplugin=/x/dagger-compiler.jar"))
        assertFalse(BuiltinPlugins.isRewrittenXplugin("-classpath"))
    }

    @Test fun warningNamesJarBuiltinAndSilenceFlag() {
        val w = BuiltinPlugins.warning(BuiltinPlugins.detect(
            CompileRequest(compilerPluginClasspath = listOf("/x/" + SERIALIZATION_JAR))))
        assertTrue("[warning]" in w, "must be a Bazel-visible [warning]")
        assertTrue(SERIALIZATION_JAR in w, "must name the offending jar")
        assertTrue("--plugins=serialization" in w, "must name the builtin replacement")
        assertTrue("warn_builtin_plugin_rewrite=false" in w, "must point at the silence flag")
    }

    @Test fun warningEmptyWhenNothingRewritten() {
        assertEquals("", BuiltinPlugins.warning(emptyList()))
    }
}
