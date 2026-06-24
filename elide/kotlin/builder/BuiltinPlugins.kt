package elide.kotlin.builder

/**
 * Rewrites rules_kotlin-delivered `-Xplugin=<jar>` flags that duplicate a
 * compiler plugin already bundled in Elide.
 *
 * Elide warns that a raw `-Xplugin` loads the jar as-is (version-mismatch / load
 * risk) and recommends its builtin (`--plugins=<name>`), which is pinned to the
 * embedded compiler. On the fast path we therefore drop the matching `-Xplugin`
 * and enable the builtin instead, and surface a single Bazel-visible `[warning]`
 * (silenceable via //config/kotlinc:warn_builtin_plugin_rewrite).
 */
object BuiltinPlugins {
    // Jar-basename substring -> Elide builtin name passed to `--plugins=<name>`.
    // The four builtins Elide exposes via `--plugins` (per `elide kotlinc --help`:
    // metro, serialization, atomicfu, power-assert). Substrings are the
    // compiler-*plugin* jar names (not runtimes), and deliberately omit the
    // `kotlin`/`kotlinx` prefix so both `kotlin-serialization-compiler-plugin.jar`
    // and `kotlinx-serialization-compiler-plugin.jar` match. A wrong entry would
    // silently drop a real plugin, so keep these specific.
    private val MAP = listOf(
        "serialization-compiler-plugin" to "serialization",
        "power-assert-compiler-plugin" to "power-assert",
        "atomicfu-compiler-plugin" to "atomicfu",
        "metro-compiler" to "metro",
    )

    /** A `-Xplugin` jar that duplicates an Elide builtin. */
    data class Rewrite(val jar: String, val builtin: String)

    /** Last path segment, tolerant of both `/` and Windows `\` separators. */
    internal fun basename(path: String): String =
        path.substringAfterLast('/').substringAfterLast('\\')

    private fun builtinFor(jar: String): String? {
        val base = basename(jar)
        for ((needle, name) in MAP) {
            if (needle in base) return name
        }
        return null
    }

    /** True for a `-Xplugin=<jar>` flag whose jar duplicates a builtin (drop it). */
    fun isRewrittenXplugin(flag: String): Boolean =
        flag.startsWith("-Xplugin=") && builtinFor(flag.removePrefix("-Xplugin=")) != null

    /**
     * The `-Xplugin` jars (from `--compiler_plugin_classpath` and any that ride
     * in `--kotlin_passthrough_flags`) that duplicate a builtin, deduped by jar.
     */
    fun detect(req: CompileRequest): List<Rewrite> {
        val passthroughJars = req.passthroughFlags
            .filter { it.startsWith("-Xplugin=") }
            .map { it.removePrefix("-Xplugin=") }
        val byJar = LinkedHashMap<String, Rewrite>()
        for (jar in req.compilerPluginClasspath + passthroughJars) {
            val name = builtinFor(jar) ?: continue
            byJar.putIfAbsent(jar, Rewrite(jar, name))
        }
        return byJar.values.toList()
    }

    /** Distinct builtin names to enable via `--plugins=` for [rewrites]. */
    fun builtinNames(rewrites: List<Rewrite>): List<String> =
        rewrites.map { it.builtin }.distinct()

    /** Bazel-visible warning text for [rewrites], or "" when there is nothing to report. */
    fun warning(rewrites: List<Rewrite>): String {
        if (rewrites.isEmpty()) return ""
        val lines = rewrites.joinToString("\n") { "  - ${basename(it.jar)} -> --plugins=${it.builtin}" }
        return "[warning] elide_kotlin_builder: dropped -Xplugin jar(s) that duplicate an Elide " +
            "builtin compiler plugin and enabled the version-pinned builtin instead:\n" + lines +
            "\n  (silence: --@rules_elide//config/kotlinc:warn_builtin_plugin_rewrite=false)\n"
    }
}
