package elide.kotlin.builder

import com.google.devtools.build.lib.view.proto.Deps
import java.io.File

object Jdeps {
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
