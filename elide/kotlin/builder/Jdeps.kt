package elide.kotlin.builder

import com.google.devtools.build.lib.view.proto.Deps
import java.io.File

object Jdeps {
    /** Enforce source-level direct dependencies using Elide's native classification. */
    fun check(path: String, directDeps: List<String>, classpath: List<String>, mode: String): Pair<Int, String> {
        if (mode.equals("off", ignoreCase = true)) return 0 to ""
        val report = File(path).inputStream().use { Deps.Dependencies.parseFrom(it) }
        val missing = report.dependencyList.filter {
            it.kind == Deps.Dependency.Kind.EXPLICIT && it.path in classpath && it.path !in directDeps
        }.map { it.path }.distinct()
        if (missing.isEmpty()) return 0 to ""
        val error = mode.equals("error", ignoreCase = true)
        return (if (error) 1 else 0) to
            "[${if (error) "error" else "warning"}] strict Kotlin deps: add direct dependencies for ${missing.joinToString()}\n"
    }

    /**
     * Writes a real `.jdeps` (`Deps.Dependencies`) classifying each classpath entry,
     * using the set of actually-referenced entries that `elide kotlinc/javac
     * --report-used-deps` recorded (Elide 1.3.2, WHIPLASH #1002/#1005). Each
     * `classpath` entry is marked EXPLICIT (used and a direct dep), IMPLICIT (used
     * transitive dep), or UNUSED — the data Bazel/rules_kotlin consume for
     * strict-deps / unused-deps / reduced-classpath.
     */
    fun write(path: String, ruleLabel: String, classpath: List<String>, directDeps: List<String>, usedReport: File) {
        val used = usedReport.readLines().map(String::trim).filter(String::isNotEmpty).toSet()
        val direct = directDeps.toSet()
        val deps = Deps.Dependencies.newBuilder()
            .setRuleLabel(ruleLabel)
            .setSuccess(true)
        for (entry in classpath) {
            val kind = when {
                entry !in used -> Deps.Dependency.Kind.UNUSED
                entry in direct -> Deps.Dependency.Kind.EXPLICIT
                else -> Deps.Dependency.Kind.IMPLICIT
            }
            deps.addDependency(Deps.Dependency.newBuilder().setPath(entry).setKind(kind))
        }
        File(path).outputStream().use { deps.build().writeTo(it) }
    }

    /**
     * Writes a valid-but-empty `Deps` proto (no per-dependency classification).
     * Fallback for when no used-deps report is available (no classpath, or the
     * report could not be produced) — keeps the declared `.jdeps` output present.
     */
    fun writeStub(path: String, ruleLabel: String) {
        val deps = Deps.Dependencies.newBuilder()
            .setRuleLabel(ruleLabel)
            .setSuccess(true)
            .build()
        File(path).outputStream().use { deps.writeTo(it) }
    }
}
