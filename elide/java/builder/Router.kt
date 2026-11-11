package elide.java.builder

import java.io.File

enum class Route { ELIDE, STOCK }

data class Decision(val route: Route, val reason: String)

/** Chooses `elide javac` when it can reproduce JavaBuilder's result exactly, else the stock JavaBuilder. */
object Router {
    /** javac options Elide cannot honor yet; `-h` is read as Elide's help flag (elide-dev/runtime#2954). */
    private val UNSUPPORTED_JAVACOPTS = listOf("-h", "-J", "--processor-module-path", "--module-source-path")

    private val NATIVE_METHOD = Regex("""\bnative\b[^;{=]*\(""")

    /**
     * Error Prone runs for `-Xep…` options, or for a processor path without declared processors: that is how
     * `java_plugin`s without a processor class (e.g. NullAway) reach JavaBuilder's Error Prone.
     */
    fun needsErrorProne(req: Request): Boolean =
        req.javacopts.any { it.startsWith("-Xep") } || (req.processorpath.isNotEmpty() && req.processors.isEmpty())

    fun decide(req: Request, caps: Capabilities): Decision {
        if (req.unknown.isNotEmpty()) return Decision(Route.STOCK, "unsupported JavaBuilder flags ${req.unknown}")
        if (req.reduceClasspathMode == "JAVABUILDER_REDUCED") return Decision(Route.STOCK, "JavaBuilder classpath reduction")
        if (req.processors.isNotEmpty() && !caps.annotationProcessing) return Decision(Route.STOCK, "annotation processors")
        if (req.generatedClassOutput != null) return Decision(Route.STOCK, "generated class output")
        if (req.sources.isEmpty() && req.sourceJars.isEmpty()) return Decision(Route.STOCK, "no sources")
        req.javacopts.firstOrNull { o -> UNSUPPORTED_JAVACOPTS.any { o == it || o.startsWith("$it:") || (it == "-J" && o.startsWith(it)) } }
            ?.let { return Decision(Route.STOCK, "javac option $it") }
        if (needsErrorProne(req) && !caps.javacPlugins) {
            return Decision(Route.STOCK, "Error Prone/javac plugins need Elide with javacPlugins (elide-dev/runtime#2953)")
        }
        if (req.nativeHeaderOutput != null && req.sources.any { declaresNative(it) }) {
            return Decision(Route.STOCK, "native methods need javac -h (elide-dev/runtime#2954)")
        }
        return Decision(Route.ELIDE, "")
    }

    private fun declaresNative(path: String): Boolean =
        path.endsWith(".java") && File(path).let { it.isFile && NATIVE_METHOD.containsMatchIn(it.readText()) }
}
