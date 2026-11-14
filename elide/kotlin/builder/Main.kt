package elide.kotlin.builder

import com.google.devtools.build.lib.worker.WorkerProtocol.Input
import elide.builder.worker.ResidentWorker
import elide.builder.worker.ResidentPool
import elide.builder.worker.WorkerLoop
import java.io.File
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
        val nativeTools: Boolean = false,
        // Most resident Elide processes to keep (`--resident_workers=<n>`); 0 picks a default.
        val residentWorkers: Int = 0,
    )

    fun splitConfig(argv: List<String>): Pair<Config, List<String>> {
        var elide = ""; var fallback = ""; var resident = false; var record = ""
        var quietPluginRewrite = false
        var nativeTools = false
        var residentWorkers = 0
        val rest = mutableListOf<String>()
        for (a in argv) when {
            a.startsWith("--elide=") -> elide = a.substringAfter("=")
            a.startsWith("--fallback_builder=") -> fallback = a.substringAfter("=")
            a == "--resident_worker" -> resident = true
            a.startsWith("--resident_workers=") -> residentWorkers = a.substringAfter("=").toInt()
            a.startsWith("--worker_record=") -> record = a.substringAfter("=")
            a == "--quiet_plugin_rewrite" -> quietPluginRewrite = true
            a == "--native_tools" -> nativeTools = true
            else -> rest += a
        }
        return Config(elide, fallback, resident, record, quietPluginRewrite, nativeTools, residentWorkers) to rest
    }

    // Probed once per elide binary (a worker serves one toolchain).
    private val probed = HashMap<String, Capabilities>()

    @Synchronized
    private fun capabilities(elide: String): Capabilities =
        if (elide.isEmpty()) Capabilities.NONE else probed.getOrPut(elide) { Capabilities.probe(elide) }

    /** Handle one unit of work. Returns (exitCode, capturedOutput). */
    internal fun handle(
        cfg: Config,
        rest: List<String>,
        resident: ResidentPool? = null,
        inputs: List<Input> = emptyList(),
    ): Pair<Int, String> {
        val ff = rest.first { it.startsWith("--flagfile=") }.substringAfter("=")
        val req = Flagfile.parse(Flagfile.readTokens(Paths.get(ff)))
        val wd = File(".")
        val caps = capabilities(cfg.elide)
        if (Router.route(req, cfg.nativeTools, caps.kotlinCompilerPlugins).route == Route.FALLBACK) {
            return Fallback.run(cfg.fallback, ff, wd)
        }

        // -Xplugin jars duplicating an Elide builtin are rewritten to `--plugins=`
        // in ElideCompile.plan; surface that once as a Bazel `[warning]` (unless
        // silenced). Prepended to the captured output, which becomes WorkResponse.output.
        val rewriteWarning = if (cfg.quietPluginRewrite) "" else BuiltinPlugins.warning(BuiltinPlugins.detect(req))

        // Unpack generated sources from --source_jars (KAPT/KSP) so the compile can
        // resolve references to generated symbols; clean up the temp dir after.
        val srcJarDir = if (req.sourceJars.isNotEmpty()) Files.createTempDirectory("elide-srcjars").toFile() else null
        // Ask elide to record used classpath entries so we can write a real .jdeps
        // (Elide 1.3.2, WHIPLASH #1002/#1005). Only meaningful when there is a
        // classpath to classify and a jdeps output is requested.
        val usedReport = if (!cfg.nativeTools && req.jdeps != null && req.classpath.isNotEmpty()) {
            File.createTempFile("elide-useddeps", ".txt")
        } else {
            null
        }
        try {
            val extraSources = srcJarDir?.let { ElideCompile.extractSourceJars(req.sourceJars, it) } ?: emptyList()
            val cmds = ElideCompile.plan(req, cfg.elide, extraSources, usedReport?.path, cfg.nativeTools, caps.kotlinCompilerPlugins)
            val (code, compileOut) = compileCmds(cmds, resident, inputs, wd)
            val out = rewriteWarning + compileOut
            if (code == 0 && !cfg.nativeTools) req.jdeps?.let { jdeps ->
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
            if (code == 0 && cfg.nativeTools && req.jdeps != null) {
                val (depsCode, diagnostic) = Jdeps.check(req.jdeps, req.directDependencies, req.classpath, req.strictKotlinDeps)
                return depsCode to (out + diagnostic)
            }
            return code to out
        } finally {
            usedReport?.delete()
            srcJarDir?.deleteRecursively()
        }
    }

    /**
     * Runs the planned commands. With a [resident] worker, forwards the kotlinc
     * compile (`cmds[0]`) to it and runs any remaining commands (srcjar) one-shot;
     * on any resident failure, one-shots the whole plan (the worker restarts on
     * the next compile). Without a resident, one-shots everything.
     */
    private fun compileCmds(
        cmds: List<List<String>>,
        resident: ResidentPool?,
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
            // Singleplex requests are handled serially and multiplex requests concurrently;
            // WorkRequest.cancel is not honored. With `--resident_worker`, kotlinc compiles
            // are forwarded to a pool of warm `elide kotlinc --persistent_worker` processes,
            // created lazily with the resolved elide path and shared by every request.
            var resident: ResidentPool? = null
            val residentLock = Any()
            try {
                WorkerLoop.serve(System.`in`, System.out) { wr ->
                    val (cfg2, r) = splitConfig(wr.argumentsList)
                    val merged = Config(
                        cfg2.elide.ifEmpty { cfg.elide },
                        cfg2.fallback.ifEmpty { cfg.fallback },
                        cfg.resident || cfg2.resident,
                        cfg.record.ifEmpty { cfg2.record },
                        cfg.quietPluginRewrite || cfg2.quietPluginRewrite,
                        cfg.nativeTools || cfg2.nativeTools,
                        cfg.residentWorkers,
                    )
                    val forward = synchronized(residentLock) {
                        if (resident == null && merged.resident && merged.elide.isNotEmpty()) {
                            // Record path: the `--worker_record=` startup flag (reaches the
                            // worker), falling back to the env var for direct/replay runs.
                            val recPath = merged.record.ifEmpty { System.getenv("ELIDE_WORKER_RECORD") ?: "" }
                            val rec = if (recPath.isNotEmpty()) FileOutputStream(recPath) else null
                            // A recording is one request stream, so it gets a single process.
                            val size = if (rec != null) 1 else merged.residentWorkers.takeIf { it > 0 } ?: ResidentPool.defaultSize()
                            resident = ResidentPool(size) { ResidentWorker(merged.elide, "kotlinc", rec) }
                        }
                        resident
                    }
                    runCatching { handle(merged, r, forward, wr.inputsList) }
                        .getOrElse { 1 to (it.message ?: "error") }
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
