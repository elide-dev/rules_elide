package elide.java.builder

import java.io.File
import java.nio.file.Files
import java.util.zip.ZipInputStream

/** Translates a JavaBuilder [Request] into one `elide javac` invocation. */
object ElideJavac {
    /**
     * Error Prone flags JavaBuilder consumes itself (`-Xep…`); with plugins they become one
     * `-Xplugin:ErrorProne …` argument, as a javac on HotSpot would receive them.
     */
    fun errorProneArgs(javacopts: List<String>): Pair<List<String>, String?> {
        val ep = javacopts.filter { it.startsWith("-Xep") }
        val rest = javacopts.filterNot { it.startsWith("-Xep") }
        return rest to ("-Xplugin:ErrorProne" + ep.joinToString("") { " $it" })
    }

    /**
     * Builds the command. [errorProneJars] supplies Error Prone itself (rules_java bundles it in
     * JavaBuilder_deploy.jar); [extraSources] are `.java` files unpacked from `--source_jars`.
     */
    fun plan(
        req: Request,
        elide: String,
        errorProneJars: List<String>,
        extraSources: List<String>,
        sep: String,
        generatedSources: String? = null,
    ): List<String> {
        val cmd = mutableListOf(elide, "javac", "--jar", req.output)
        req.depsProto?.let { cmd += listOf("--jdeps", it) }
        req.targetLabel?.let { cmd += listOf("--target-label", it) }
        cmd += "--"
        val plugins = Router.needsErrorProne(req)
        val (opts, plugin) = if (plugins) errorProneArgs(req.javacopts) else req.javacopts to null
        cmd += opts
        when {
            req.system != null -> cmd += listOf("--system", req.system)
            req.bootclasspath.isNotEmpty() -> cmd += listOf("-bootclasspath", req.bootclasspath.joinToString(sep))
        }
        if (req.classpath.isNotEmpty()) cmd += listOf("-classpath", req.classpath.joinToString(sep))
        // JavaBuilder never discovers processors implicitly: only declared --processors run.
        if (req.processors.isEmpty()) cmd += "-proc:none" else cmd += listOf("-processor", req.processors.joinToString(","))
        if (generatedSources != null) cmd += listOf("-s", generatedSources)
        val processorpath = (if (plugin != null) errorProneJars else emptyList()) + req.processorpath
        if (processorpath.isNotEmpty() && (plugin != null || req.processors.isNotEmpty())) {
            cmd += listOf("-processorpath", processorpath.joinToString(sep))
        }
        if (plugin != null) cmd += plugin
        cmd += req.sources
        cmd += extraSources
        return cmd
    }

    /** Unpacks the `.java` entries of [jars] under [dir]; returns their paths. */
    fun extractSourceJars(jars: List<String>, dir: File): List<String> {
        val out = mutableListOf<String>()
        for ((index, jar) in jars.withIndex()) {
            val root = File(dir, index.toString())
            ZipInputStream(File(jar).inputStream().buffered()).use { zip ->
                while (true) {
                    val entry = zip.nextEntry ?: break
                    if (entry.isDirectory || !entry.name.endsWith(".java")) continue
                    val target = File(root, entry.name).canonicalFile
                    require(target.toPath().startsWith(root.canonicalFile.toPath())) { "unsafe source jar entry ${entry.name}" }
                    target.parentFile.mkdirs()
                    Files.copy(zip, target.toPath())
                    out += target.path
                }
            }
        }
        return out
    }

    /** Runs [cmd] in [wd]; returns (exit code, combined output). */
    fun run(cmd: List<String>, wd: File): Pair<Int, String> {
        val log = File.createTempFile("elide-javac", ".log")
        try {
            val p = ProcessBuilder(cmd).directory(wd).redirectErrorStream(true).redirectOutput(log).start()
            val code = p.waitFor()
            return code to log.readText()
        } finally {
            log.delete()
        }
    }
}
