package elide.kotlin.builder

import java.nio.file.Files
import java.nio.file.Path

/** Parsed, typed view of the rules_kotlin KotlinBuilder flagfile fields we consume. */
data class CompileRequest(
    val output: String? = null,
    val abiJar: String? = null,
    val jdeps: String? = null,
    val srcjar: String? = null,
    val moduleName: String? = null,
    val targetLabel: String? = null,
    val sources: List<String> = emptyList(),
    val sourceJars: List<String> = emptyList(),
    val classpath: List<String> = emptyList(),
    val directDependencies: List<String> = emptyList(),
    val friendPaths: List<String> = emptyList(),
    val passthroughFlags: List<String> = emptyList(),
    val javacOpts: List<String> = emptyList(),
    val strictKotlinDeps: String = "off",
    val processors: List<String> = emptyList(),
    val processorPath: List<String> = emptyList(),
    val compilerPluginClasspath: List<String> = emptyList(),
    val compilerPluginOptions: List<String> = emptyList(),
    val stubsPluginClasspath: List<String> = emptyList(),
    val stubsPluginOptions: List<String> = emptyList(),
    val apiVersion: String? = null,
    val languageVersion: String? = null,
    val raw: Map<String, List<String>> = emptyMap(),
)

object Flagfile {
    /** Reads `--flagfile=<path>` content (one token per line) into tokens. */
    fun readTokens(flagfilePath: Path): List<String> =
        Files.readAllLines(flagfilePath).filter { it.isNotEmpty() }

    fun parse(tokens: List<String>): CompileRequest {
        val map = LinkedHashMap<String, MutableList<String>>()
        var cur: MutableList<String>? = null
        for (t in tokens) {
            if (t.startsWith("--")) {
                cur = map.getOrPut(t) { mutableListOf() }
            } else {
                cur?.add(t)
            }
        }
        fun first(k: String) = map[k]?.firstOrNull()
        fun list(k: String) = map[k]?.toList() ?: emptyList()
        return CompileRequest(
            output = first("--output"),
            abiJar = first("--abi_jar"),
            jdeps = first("--kotlin_output_jdeps"),
            srcjar = first("--kotlin_output_srcjar"),
            moduleName = first("--kotlin_module_name"),
            targetLabel = first("--target_label"),
            sources = list("--sources"),
            sourceJars = list("--source_jars"),
            classpath = list("--classpath"),
            directDependencies = list("--direct_dependencies"),
            friendPaths = list("--kotlin_friend_paths"),
            passthroughFlags = list("--kotlin_passthrough_flags"),
            javacOpts = list("--javacopts"),
            strictKotlinDeps = first("--strict_kotlin_deps") ?: "off",
            processors = list("--processors"),
            processorPath = list("--processorpath"),
            compilerPluginClasspath = list("--compiler_plugin_classpath"),
            compilerPluginOptions = list("--compiler_plugin_options"),
            stubsPluginClasspath = list("--stubs_plugin_classpath"),
            stubsPluginOptions = list("--stubs_plugin_options"),
            apiVersion = first("--kotlin_api_version"),
            languageVersion = first("--kotlin_language_version"),
            raw = map.mapValues { it.value.toList() },
        )
    }
}
