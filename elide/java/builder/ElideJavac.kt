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

    // JavaBuilder receives toolchain defaults before target javacopts. Its ReleaseOptionNormalizer
    // lets a later --release replace -source/-target, and vice versa. javac itself rejects both.
    private fun languageOptions(options: List<String>): List<String> {
        if (options.none { it == "--release" || it.startsWith("--release=") }) return options
        val rest = mutableListOf<String>()
        var source: String? = null
        var target: String? = null
        var release: String? = null
        val args = options.iterator()
        while (args.hasNext()) {
            val opt = args.next()
            when {
                opt == "--release" || opt.startsWith("--release=") -> {
                    release = if (opt == "--release") {
                        if (!args.hasNext()) return options
                        args.next()
                    } else opt.substringAfter('=')
                    source = null
                    target = null
                }
                opt == "-source" || opt == "-target" -> {
                    if (!args.hasNext()) return options
                    if (opt == "-source") source = args.next() else target = args.next()
                    release = null
                }
                else -> rest += opt
            }
        }
        release?.let { rest += listOf("--release", it) }
        source?.let { rest += listOf("-source", it) }
        target?.let { rest += listOf("-target", it) }
        return rest
    }

    /**
     * Builds the command. [errorProneJars] supplies Error Prone itself (rules_java bundles it in
     * JavaBuilder_deploy.jar); [extraSources] are `.java` files unpacked from `--source_jars`.
     * [passSystem] forwards JavaBuilder's `--system` (the toolchain's JDK class library) to javac.
     */
    fun plan(
        req: Request,
        elide: String,
        errorProneJars: List<String>,
        extraSources: List<String>,
        sep: String,
        generatedSources: String? = null,
        passSystem: Boolean = false,
    ): List<String> {
        val cmd = mutableListOf(elide, "javac", "--jar", req.output)
        req.depsProto?.let { cmd += listOf("--jdeps", it) }
        req.targetLabel?.let { cmd += "--target-label=$it" }
        cmd += "--"
        val plugins = Router.needsErrorProne(req)
        val (opts, plugin) = if (plugins) errorProneArgs(req.javacopts) else req.javacopts to null
        val effectiveOpts = languageOptions(opts)
        cmd += effectiveOpts
        when {
            "--release" in effectiveOpts -> Unit // javac selects its own system API for the release.
            // Without [passSystem] the compile uses the class library of the JDK embedded in Elide, which
            // skips the per-compile cost of opening the toolchain's system image (elide-dev/runtime#2986).
            req.system != null -> if (passSystem) cmd += listOf("--system", req.system)
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

    /**
     * Worker-form args for a resident `elide javac --persistent_worker`: the command from [plan]
     * without the leading `elide javac`, which is the resident process itself. The `--` separator
     * stays; the worker uses it to split Elide options from javac arguments.
     */
    fun workerArgs(cmd: List<String>): List<String> = cmd.drop(2)

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
