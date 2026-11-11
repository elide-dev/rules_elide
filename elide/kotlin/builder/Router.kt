package elide.kotlin.builder

enum class Route { FAST, FALLBACK }

data class Routing(val route: Route, val reason: String)

object Router {
    // Plugin jars that signal a path Elide does not yet handle. jvm-abi-gen is
    // explicitly excluded: Elide runs it itself for the abijar.
    private val KSP_MARKERS = listOf("symbol-processing", "/ksp", "ksp-")

    private fun anyKsp(jars: List<String>) =
        jars.any { j -> KSP_MARKERS.any { j.contains(it) } }

    /**
     * A payload plugin Elide can run itself: its jars duplicate an Elide builtin (enabled with `--plugins=`)
     * and it carries no options. Elide rejects other `-Xplugin` jars (only bundled plugins load), so those
     * compiles must stay on the stock builder rather than drop the plugin.
     */
    private fun isBuiltin(plugin: PayloadPlugin): Boolean =
        plugin.options.isEmpty() && plugin.classpath.isNotEmpty() &&
            plugin.classpath.all { BuiltinPlugins.builtinFor(it) != null }

    fun route(req: CompileRequest, nativeTools: Boolean = false): Routing {
        req.payloadPlugins.firstOrNull { it.compiles && !isBuiltin(it) }?.let {
            return Routing(Route.FALLBACK, "compiler plugin ${it.id.ifEmpty { it.classpath.joinToString() }} is not an Elide builtin")
        }
        req.compilerPluginClasspath.firstOrNull {
            "jvm-abi-gen" !in it && BuiltinPlugins.builtinFor(it) == null && KSP_MARKERS.none { m -> it.contains(m) }
        }?.let { return Routing(Route.FALLBACK, "compiler plugin ${BuiltinPlugins.basename(it)} is not an Elide builtin") }
        if (req.kaptSources != null && req.payloadPlugins.any { it.stubs }) {
            return Routing(Route.FALLBACK, "KAPT stubs compiler plugins")
        }
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
