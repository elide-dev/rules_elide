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
}
