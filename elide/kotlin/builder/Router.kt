package elide.kotlin.builder

enum class Route { FAST, FALLBACK }

data class Routing(val route: Route, val reason: String)

object Router {
    // Plugin jars that signal a path Elide does not yet handle. jvm-abi-gen is
    // explicitly excluded: Elide runs it itself for the abijar.
    private val KSP_MARKERS = listOf("symbol-processing", "/ksp", "ksp-")

    private fun anyKsp(jars: List<String>) =
        jars.any { j -> KSP_MARKERS.any { j.contains(it) } }

    fun route(req: CompileRequest, nativeTools: Boolean = false): Routing {
        if (req.kspSources != null) {
            if (!nativeTools || req.raw["--experimental_psi_resolution"]?.contains("true") == true)
                return Routing(Route.FALLBACK, "KSP2 requires native tools without PSI override")
            return Routing(Route.FAST, "Elide KSP2")
        }
        if (nativeTools && req.kaptSources != null && req.stubsPluginClasspath.isEmpty() && req.stubsPluginOptions.isEmpty() && req.javacOpts.all { it.startsWith("-A") })
            return Routing(Route.FAST, "Elide header-based KAPT")
        if (req.processors.isNotEmpty())
            return Routing(Route.FALLBACK, "KAPT processors present")
        if (anyKsp(req.compilerPluginClasspath) || anyKsp(req.stubsPluginClasspath))
            return Routing(Route.FALLBACK, "KSP plugin present")
        return Routing(Route.FAST, "plain Kotlin/Java compile")
    }
}
