package elide.kotlin.builder

enum class Route { FAST, FALLBACK }

data class Routing(val route: Route, val reason: String)

object Router {
    // Plugin jars that signal a path Elide does not yet handle. jvm-abi-gen is
    // explicitly excluded: Elide runs it itself for the abijar.
    private val KSP_MARKERS = listOf("symbol-processing", "/ksp", "ksp-")

    private fun anyKsp(jars: List<String>) =
        jars.any { j -> KSP_MARKERS.any { j.contains(it) } }

    fun route(req: CompileRequest): Routing {
        if (req.processors.isNotEmpty())
            return Routing(Route.FALLBACK, "KAPT processors present")
        if (anyKsp(req.compilerPluginClasspath) || anyKsp(req.stubsPluginClasspath))
            return Routing(Route.FALLBACK, "KSP plugin present")
        return Routing(Route.FAST, "plain Kotlin/Java compile")
    }
}
