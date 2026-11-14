package elide.java.builder

import com.google.devtools.build.lib.view.proto.Deps
import java.io.File
import java.util.jar.JarFile

/** JavaBuilder's strict-deps check over the `.jdeps` that `elide javac --jdeps` writes. */
object StrictDeps {
    /** Returns (exit code, diagnostic). */
    fun check(req: Request): Pair<Int, String> {
        val mode = req.strictJavaDeps.uppercase()
        if (mode == "OFF" || req.depsProto == null || !File(req.depsProto).isFile) return 0 to ""
        val report = File(req.depsProto).inputStream().use { Deps.Dependencies.parseFrom(it) }
        val direct = req.directDependencies.toSet()
        val classpath = req.classpath.toSet()
        val missing = report.dependencyList
            .filter { it.kind == Deps.Dependency.Kind.EXPLICIT && it.path in classpath && it.path !in direct }
            .map { it.path }
            .distinct()
        if (missing.isEmpty()) return 0 to ""
        val error = mode != "WARN"
        val labels = missing.map { targetLabel(it) ?: it }
        val target = req.targetLabel ?: "<target>"
        val message = buildString {
            append(if (error) "error" else "warning")
            append(": [strict] Using types from indirect dependencies of ").append(target).append(":\n")
            labels.forEach { append("  ").append(it).append('\n') }
            append("** Please add the following dependencies:\n  ").append(labels.joinToString(" ")).append(" to ").append(target).append('\n')
            append("** You can use the following buildozer command:\nbuildozer 'add deps ")
                .append(labels.joinToString(" ")).append("' ").append(target).append('\n')
        }
        return (if (error) 1 else 0) to message
    }

    /** ijars and header jars record their owner in the manifest, as JavaBuilder reads it. */
    private fun targetLabel(jar: String): String? = try {
        JarFile(jar).use { it.manifest?.mainAttributes?.getValue("Target-Label") }
    } catch (e: Exception) {
        null
    }
}
