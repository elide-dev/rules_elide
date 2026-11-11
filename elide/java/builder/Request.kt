package elide.java.builder

import java.nio.file.Files
import java.nio.file.Path

/** One JavaBuilder compile request, as rules_java's JavaCompile action passes it. */
data class Request(
    val output: String,
    val nativeHeaderOutput: String?,
    val manifestProto: String?,
    val depsProto: String?,
    val generatedSourcesOutput: String?,
    val generatedClassOutput: String?,
    val sources: List<String>,
    val sourceJars: List<String>,
    val classpath: List<String>,
    val bootclasspath: List<String>,
    val system: String?,
    val processorpath: List<String>,
    val processors: List<String>,
    val javacopts: List<String>,
    val directDependencies: List<String>,
    val strictJavaDeps: String,
    val targetLabel: String?,
    val injectingRuleKind: String?,
    /** Flags this shim does not understand; any of them routes the request to the stock JavaBuilder. */
    val unknown: List<String>,
) {
    companion object {
        /** Flags taking a list of values (until the next `--flag`). */
        private val LISTS = setOf(
            "--sources", "--source_jars", "--classpath", "--bootclasspath", "--processorpath", "--processors",
            "--direct_dependencies",
        )

        /** Flags taking exactly one value. */
        private val SINGLES = setOf(
            "--output", "--native_header_output", "--output_manifest_proto", "--output_deps_proto",
            "--generated_sources_output", "--generated_class_output", "--system", "--strict_java_deps",
            "--target_label", "--injecting_rule_kind", "--experimental_fix_deps_tool",
        )

        /** Boolean flags with no value that do not change the result (jar compression is always on). */
        private val SWITCHES = setOf("--compress_jar")

        /**
         * Expands `@paramfile` arguments (one argument per line; shell-quoted lines are unquoted). Workers may
         * receive arguments already expanded (BuildBuddy expands flag files for remote persistent workers), and
         * values such as canonical labels (`@@repo//pkg:name`) also start with `@`, so only an `@path` naming
         * an existing file is expanded.
         */
        fun expand(argv: List<String>): List<String> = argv.flatMap { arg ->
            val path = if (arg.startsWith("@") && !arg.startsWith("@@")) Path.of(arg.substring(1)) else null
            if (path != null && Files.isRegularFile(path)) {
                Files.readAllLines(path).filter { it.isNotEmpty() }.map(::unquote)
            } else {
                listOf(arg)
            }
        }

        internal fun unquote(line: String): String =
            if (line.length >= 2 && line.startsWith("'") && line.endsWith("'")) {
                line.substring(1, line.length - 1).replace("'\\''", "'")
            } else line

        fun parse(argv: List<String>): Request {
            val args = expand(argv)
            val lists = mutableMapOf<String, MutableList<String>>()
            val singles = mutableMapOf<String, String>()
            val javacopts = mutableListOf<String>()
            val unknown = mutableListOf<String>()
            var i = 0
            while (i < args.size) {
                val a = args[i]
                when {
                    a == "--javacopts" -> {
                        i++
                        while (i < args.size && args[i] != "--") javacopts += args[i++]
                        i++ // skip the terminating `--`
                        continue
                    }
                    a in LISTS -> {
                        val values = lists.getOrPut(a) { mutableListOf() }
                        i++
                        while (i < args.size && !args[i].startsWith("--")) values += args[i++]
                        continue
                    }
                    a in SINGLES && i + 1 < args.size -> { singles[a] = args[i + 1]; i += 2; continue }
                    a in SWITCHES -> { i++; continue }
                    else -> { unknown += a; i++ }
                }
            }
            return Request(
                output = singles["--output"] ?: error("JavaBuilder request without --output"),
                nativeHeaderOutput = singles["--native_header_output"],
                manifestProto = singles["--output_manifest_proto"],
                depsProto = singles["--output_deps_proto"],
                generatedSourcesOutput = singles["--generated_sources_output"],
                generatedClassOutput = singles["--generated_class_output"],
                sources = lists["--sources"].orEmpty(),
                sourceJars = lists["--source_jars"].orEmpty(),
                classpath = lists["--classpath"].orEmpty(),
                bootclasspath = lists["--bootclasspath"].orEmpty(),
                system = singles["--system"],
                processorpath = lists["--processorpath"].orEmpty(),
                processors = lists["--processors"].orEmpty(),
                javacopts = javacopts,
                directDependencies = lists["--direct_dependencies"].orEmpty(),
                strictJavaDeps = singles["--strict_java_deps"] ?: "OFF",
                targetLabel = singles["--target_label"],
                injectingRuleKind = singles["--injecting_rule_kind"],
                unknown = unknown,
            )
        }
    }
}
