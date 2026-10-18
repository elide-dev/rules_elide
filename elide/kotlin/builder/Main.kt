package elide.kotlin.builder

import com.google.devtools.build.lib.worker.WorkerProtocol.Input
import java.io.File
import java.util.jar.JarEntry
import java.util.jar.JarOutputStream
import java.io.FileOutputStream
import java.nio.file.Files
import java.nio.file.Paths

object Main {
    // `resident` opts into forwarding kotlinc to a resident `elide kotlinc
    // --persistent_worker` (keeping the native image + incremental caches warm)
    // instead of one-shotting elide per compile. `record` is a path to tee the
    // forwarded WorkRequest stream into, for offline PGO replay. Both are gated
    // by startup flags rather than env vars: Bazel launches workers with a
    // scrubbed environment (`env -`), so an env toggle never reaches the worker;
    // the toolchain launcher injects these flags instead.
    class Config(
        val elide: String,
        val fallback: String,
        val resident: Boolean = false,
        val record: String = "",
        // Silence the `[warning]` emitted when a rules_kotlin `-Xplugin` jar
        // duplicating an Elide builtin is rewritten to `--plugins=`. Off by
        // default (warn); the toolchain launcher injects `--quiet_plugin_rewrite`
        // when //config/kotlinc:warn_builtin_plugin_rewrite=false.
        val quietPluginRewrite: Boolean = false,
    )

    fun splitConfig(argv: List<String>): Pair<Config, List<String>> {
        var elide = ""; var fallback = ""; var resident = false; var record = ""
        var quietPluginRewrite = false
        val rest = mutableListOf<String>()
        for (a in argv) when {
            a.startsWith("--elide=") -> elide = a.substringAfter("=")
            a.startsWith("--fallback_builder=") -> fallback = a.substringAfter("=")
            a == "--resident_worker" -> resident = true
            a.startsWith("--worker_record=") -> record = a.substringAfter("=")
            a == "--quiet_plugin_rewrite" -> quietPluginRewrite = true
            else -> rest += a
        }
        return Config(elide, fallback, resident, record, quietPluginRewrite) to rest
    }

    /** Handle one unit of work. Returns (exitCode, capturedOutput). */
    internal fun handle(
        cfg: Config,
        rest: List<String>,
        resident: ElideWorker? = null,
        inputs: List<Input> = emptyList(),
    ): Pair<Int, String> {
        val ff = rest.first { it.startsWith("--flagfile=") }.substringAfter("=")
        val req = Flagfile.parse(Flagfile.readTokens(Paths.get(ff)))
        val wd = File(".")
        val route = Router.route(req, elideKapt = req.isKapt && ElideCapabilities.supportsKapt(cfg.elide)).route
        if (route == Route.FALLBACK) return Fallback.run(cfg.fallback, ff, wd)
        if (route == Route.FAST_KAPT) return compileCmds(ElideCompile.planKapt(req, cfg.elide), resident, inputs, wd)

        // -Xplugin jars duplicating an Elide builtin are rewritten to `--plugins=`
        // in ElideCompile.plan; surface that once as a Bazel `[warning]` (unless
        // silenced). Prepended to the captured output, which becomes WorkResponse.output.
        val rewriteWarning = if (cfg.quietPluginRewrite) "" else BuiltinPlugins.warning(BuiltinPlugins.detect(req))

        // Unpack generated sources from --source_jars (KAPT/KSP) so the compile can
        // resolve references to generated symbols; clean up the temp dir after.
        val srcJarDir = if (req.sourceJars.isNotEmpty()) Files.createTempDirectory("elide-srcjars").toFile() else null
        // Elide that writes .jdeps itself (`--jdeps`) records the classes it read, with
        // hashes; older Elide reports used classpath entries, which Jdeps translates.
        val elideJdeps = req.jdeps != null && ElideCapabilities.supportsJdeps(cfg.elide)
        val usedReport = if (!elideJdeps && req.jdeps != null && req.classpath.isNotEmpty()) {
            File.createTempFile("elide-useddeps", ".txt")
        } else {
            null
        }
        try {
            val extraSources = srcJarDir?.let { ElideCompile.extractSourceJars(req.sourceJars, it) } ?: emptyList()
            // A target with no Kotlin sources (e.g. a Java-only srcjar) has nothing for
            // kotlinc to compile; rules_kotlin's javac action builds its classes.
            if ((req.sources + extraSources).none { it.endsWith(".kt") }) {
                return writeEmptyOutputs(req) to rewriteWarning
            }
            val cmds = ElideCompile.plan(req, cfg.elide, extraSources, usedReport?.path, req.jdeps.takeIf { elideJdeps })
            val (code, compileOut) = compileCmds(cmds, resident, inputs, wd)
            val out = rewriteWarning + compileOut
            if (code == 0 && !elideJdeps) req.jdeps?.let { jdeps ->
                // Deps.Dependencies.rule_label is the Bazel rule label (`--target_label`),
                // not the Kotlin module name. Leave empty when absent rather than emit an
                // incorrect value (WHIPLASH#1131 review follow-up).
                val ruleLabel = req.targetLabel ?: ""
                if (usedReport != null && usedReport.exists()) {
                    Jdeps.write(jdeps, ruleLabel, req.classpath, req.directDependencies, usedReport)
                } else {
                    Jdeps.writeStub(jdeps, ruleLabel)
                }
            }
            return code to out
        } finally {
            usedReport?.delete()
            srcJarDir?.deleteRecursively()
        }
    }

    /** Empty class and ABI jars plus a stub .jdeps; packs the srcjar if requested. */
    fun writeEmptyOutputs(req: CompileRequest): Int {
        listOfNotNull(req.output, req.abiJar).forEach { jar ->
            File(jar).also { it.parentFile?.mkdirs() }.outputStream().use { JarOutputStream(it).close() }
        }
        req.jdeps?.let { Jdeps.writeStub(it, req.targetLabel ?: "") }
        req.srcjar?.let { sj ->
            JarOutputStream(File(sj).also { it.parentFile?.mkdirs() }.outputStream()).use { out ->
                req.sources.forEach { src ->
                    // Same entry names as `elide jar --create --file <srcjar> <sources>`.
                    out.putNextEntry(JarEntry(src.replace('\\', '/').trimStart('/')))
                    File(src).inputStream().use { it.copyTo(out) }
                    out.closeEntry()
                }
            }
        }
        return 0
    }

    /**
     * Runs the planned commands. With a [resident] worker, forwards the kotlinc
     * compile (`cmds[0]`) to it and runs any remaining commands (srcjar) one-shot;
     * on any resident failure, one-shots the whole plan (the worker restarts on
     * the next compile). Without a resident, one-shots everything.
     */
    private fun compileCmds(
        cmds: List<List<String>>,
        resident: ElideWorker?,
        inputs: List<Input>,
        wd: File,
    ): Pair<Int, String> {
        if (resident == null || cmds.isEmpty()) return ElideCompile.run(cmds, wd)
        return try {
            val (code, out) = resident.compile(ElideCompile.kotlincWorkerArgs(cmds.first()), inputs)
            val rest = cmds.drop(1)
            if (code != 0 || rest.isEmpty()) {
                code to out
            } else {
                val (jc, jo) = ElideCompile.run(rest, wd)
                (if (jc != 0) jc else code) to (out + jo)
            }
        } catch (e: Exception) {
            // Resident unavailable/desynced: one-shot fallback for this request.
            ElideCompile.run(cmds, wd)
        }
    }

    @JvmStatic
    fun main(argv: Array<String>) {
        val (cfg, rest) = splitConfig(argv.toList())
        if (rest.contains("--persistent_worker")) {
            val stdin = System.`in`; val stdout = System.out
            // Singleplex worker: requests are handled serially; we intentionally do not
            // support multiplex or honor WorkRequest.cancel (rules_kotlin drives KotlinCompile singleplex).
            // With `--resident_worker`, kotlinc compiles are forwarded to one warm
            // `elide kotlinc --persistent_worker` (lazily created with the resolved elide path).
            var resident: ElideWorker? = null
            try {
                while (true) {
                    val wr = Worker.readRequest(stdin) ?: break
                    val (cfg2, r) = splitConfig(wr.argumentsList)
                    val merged = Config(
                        cfg2.elide.ifEmpty { cfg.elide },
                        cfg2.fallback.ifEmpty { cfg.fallback },
                        cfg.resident || cfg2.resident,
                        cfg.record.ifEmpty { cfg2.record },
                        cfg.quietPluginRewrite || cfg2.quietPluginRewrite,
                    )
                    if (resident == null && merged.resident && merged.elide.isNotEmpty()) {
                        // Record path: the `--worker_record=` startup flag (reaches the
                        // worker), falling back to the env var for direct/replay runs.
                        val recPath = merged.record.ifEmpty { System.getenv("ELIDE_WORKER_RECORD") ?: "" }
                        val rec = if (recPath.isNotEmpty()) FileOutputStream(recPath) else null
                        resident = ElideWorker(merged.elide, rec)
                    }
                    val (code, out) = runCatching { handle(merged, r, resident, wr.inputsList) }
                        .getOrElse { 1 to (it.message ?: "error") }
                    Worker.writeResponse(stdout, code, out, wr.requestId)
                }
            } finally {
                resident?.close() // clean stdin EOF → Elide exits (flushes any PGO profile)
            }
        } else {
            val (code, out) = handle(cfg, rest)
            if (out.isNotEmpty()) System.err.print(out)
            kotlin.system.exitProcess(code)
        }
    }
}
