package elide.kotlin.builder

import java.io.File
import java.nio.file.Files
import java.util.jar.JarOutputStream

/**
 * rules_kotlin's `KotlinKsp2` action, run on `elide kotlinc --ksp-sources/--ksp-classes`.
 *
 * Its flagfile names `--generated_sources_output` (a srcjar of generated Kotlin and Java) and
 * `--generated_classes_output` (generated classes and resources). Elide runs KSP itself, sharing its
 * embedded compiler, so rules_kotlin's KSP invoker is dropped from the processor path; Elide skips the
 * KSP jars there too.
 */
object Ksp {
    fun isKsp(req: CompileRequest): Boolean = req.raw.containsKey("--generated_sources_output")

    private fun CompileRequest.first(flag: String): String? = raw[flag]?.firstOrNull()

    private fun CompileRequest.list(flag: String): List<String> = raw[flag].orEmpty()

    /** The `elide kotlinc` command for [req], with [extraSources] unpacked from its source jars. */
    fun plan(req: CompileRequest, elide: String, extraSources: List<String>): List<String> = buildList {
        add(elide)
        add("kotlinc")
        req.first("--generated_sources_output")?.let { add("--ksp-sources"); add(it) }
        req.first("--generated_classes_output")?.let { add("--ksp-classes"); add(it) }
        val processorPath = req.list("--processor_classpath")
            .filterNot { File(it).name.startsWith("ksp2_invoker") }
        if (processorPath.isNotEmpty()) {
            add("--processorpath")
            add(processorPath.joinToString(File.pathSeparator))
        }
        req.list("--ksp_options").forEach { add("--processor-option"); add(it) }
        add("--")
        req.first("--module_name")?.let { add("-module-name"); add(it) }
        req.first("--jvm_target")?.let { add("-jvm-target"); add(it) }
        req.first("--language_version")?.let { add("-language-version"); add(it) }
        req.first("--api_version")?.let { add("-api-version"); add(it) }
        val libraries = req.list("--libraries")
        if (libraries.isNotEmpty()) {
            add("-cp")
            add(libraries.joinToString(File.pathSeparator))
        }
        addAll(req.sources + extraSources)
    }

    /** Runs [req] on Elide, or on rules_kotlin's KSP2 worker when Elide lacks `--ksp-sources`. */
    fun handle(cfg: Main.Config, req: CompileRequest, flagfile: String, wd: File): Pair<Int, String> {
        val srcJarDir = if (req.sourceJars.isNotEmpty()) Files.createTempDirectory("elide-ksp-srcjars").toFile() else null
        try {
            val extra = srcJarDir?.let { ElideCompile.extractSourceJars(req.sourceJars, it) } ?: emptyList()
            if ((req.sources + extra).none { it.endsWith(".kt") || it.endsWith(".java") }) {
                writeEmptyJars(req)
                return 0 to ""
            }
            if (!ElideCapabilities.supportsKsp(cfg.elide)) return Fallback.run(cfg.fallback, flagfile, wd)
            return ElideCompile.run(listOf(plan(req, cfg.elide, extra)), wd)
        } finally {
            srcJarDir?.deleteRecursively()
        }
    }

    private fun writeEmptyJars(req: CompileRequest) {
        listOfNotNull(req.first("--generated_sources_output"), req.first("--generated_classes_output")).forEach { jar ->
            File(jar).also { it.parentFile?.mkdirs() }.outputStream().use { JarOutputStream(it).close() }
        }
    }
}
