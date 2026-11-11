package elide.kotlin.builder

import kotlin.test.Test
import kotlin.test.assertEquals

class RouterTest {
    @Test fun plainCompileIsFast() {
        assertEquals(Route.FAST, Router.route(CompileRequest(sources = listOf("A.kt"))).route)
    }
    @Test fun kaptFallsBack() {
        assertEquals(Route.FALLBACK, Router.route(CompileRequest(processors = listOf("com.example.P"))).route)
    }
    @Test fun kspPluginFallsBack() {
        assertEquals(Route.FALLBACK, Router.route(CompileRequest(
            compilerPluginClasspath = listOf("external/maven/symbol-processing-cmdline.jar"))).route)
    }
    @Test fun jvmAbiGenIsNotFallback() {
        assertEquals(Route.FAST, Router.route(CompileRequest(
            compilerPluginClasspath = listOf("external/.../kotlin-jvm-abi-gen.jar"))).route)
    }
    @Test fun unsupportedJavacOptionsRetainFallback() {
        assertEquals(Route.FAST, Router.route(CompileRequest(kaptSources = "src.jar",
            processors = listOf("P"), javacOpts = listOf("-Akey=value")), true).route)
        assertEquals(Route.FALLBACK, Router.route(CompileRequest(kaptSources = "src.jar",
            processors = listOf("P"), javacOpts = listOf("--release", "21")), true).route)
    }
    @Test fun nativeKaptAndKspUseElide() {
        assertEquals(Route.FAST, Router.route(CompileRequest(kaptSources = "src.jar", processors = listOf("P")), true).route)
        assertEquals(Route.FAST, Router.route(CompileRequest(kspSources = "src.jar"), true).route)
        assertEquals(Route.FALLBACK, Router.route(CompileRequest(kaptSources = "src.jar",
            processors = listOf("P"), stubsPluginClasspath = listOf("plugin.jar")), true).route)
        assertEquals(Route.FALLBACK, Router.route(CompileRequest(kspSources = "src.jar",
            raw = mapOf("--experimental_psi_resolution" to listOf("true"))), true).route)
    }

    @Test fun payloadPluginsThatElideCannotLoadFallBack() {
        val compose = PayloadPlugin("androidx.compose.compiler.plugins.kotlin",
            listOf("bazel-out/x/kotlin-compose-compiler-plugin-embeddable-2.5.0.jar"), emptyList(),
            listOf("PLUGIN_PHASE_COMPILE", "PLUGIN_PHASE_STUBS"))
        assertEquals(Route.FALLBACK, Router.route(CompileRequest(sources = listOf("A.kt"), payloadPlugins = listOf(compose)), true).route)
        val serialization = PayloadPlugin("org.jetbrains.kotlinx.serialization",
            listOf("x/kotlin-serialization-compiler-plugin-2.5.0.jar"), emptyList(), listOf("PLUGIN_PHASE_COMPILE"))
        assertEquals(Route.FAST, Router.route(CompileRequest(sources = listOf("A.kt"), payloadPlugins = listOf(serialization)), true).route)
        val optioned = serialization.copy(options = listOf(mapOf("id" to "k", "value" to "v")))
        assertEquals(Route.FALLBACK, Router.route(CompileRequest(sources = listOf("A.kt"), payloadPlugins = listOf(optioned)), true).route)
    }
    @Test fun legacyNonBuiltinPluginsFallBack() {
        assertEquals(Route.FALLBACK, Router.route(CompileRequest(sources = listOf("A.kt"),
            compilerPluginClasspath = listOf("x/kotlin-compose-compiler-plugin-embeddable.jar"))).route)
    }
}
