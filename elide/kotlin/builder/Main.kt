package elide.kotlin.builder

import com.google.devtools.build.lib.worker.WorkerProtocol.Input
import java.io.File
import java.io.FileOutputStream
import java.nio.file.Files
import java.nio.file.Paths

object Main {
    // `resident` opts into forwarding kotlinc to a resident `elide kotlinc
    // --persistent_worker` (keeping the native image + incremental caches warm)
    // instead of one-shotting elide per compile. It is gated by the
    // `--resident_worker` startup flag rather than an env var: Bazel launches
    // workers with a scrubbed environment (`env -`), so an env toggle never
    // reaches the worker; the toolchain launcher injects this flag instead.
    class Config(val elide: String, val fallback: String, val resident: Boolean = false)

    fun splitConfig(argv: List<String>): Pair<Config, List<String>> {
        var elide = ""; var fallback = ""; var resident = false; val rest = mutableListOf<String>()
        for (a in argv) when {
            a.startsWith("--elide=") -> elide = a.substringAfter("=")
            a.startsWith("--fallback_builder=") -> fallback = a.substringAfter("=")
            a == "--resident_worker" -> resident = true
            else -> rest += a
        }
        return Config(elide, fallback, resident) to rest
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
        if (Router.route(req).route == Route.FALLBACK) return Fallback.run(cfg.fallback, ff, wd)

        // Unpack generated sources from --source_jars (KAPT/KSP) so the compile can
        // resolve references to generated symbols; clean up the temp dir after.
        val srcJarDir = if (req.sourceJars.isNotEmpty()) Files.createTempDirectory("elide-srcjars").toFile() else null
        // Ask elide to record used classpath entries so we can write a real .jdeps
        // (Elide 1.3.2, WHIPLASH #1002/#1005). Only meaningful when there is a
        // classpath to classify and a jdeps output is requested.
        val usedReport = if (req.jdeps != null && req.classpath.isNotEmpty()) {
            File.createTempFile("elide-useddeps", ".txt")
        } else {
            null
        }
        try {
            val extraSources = srcJarDir?.let { ElideCompile.extractSourceJars(req.sourceJars, it) } ?: emptyList()
            val cmds = ElideCompile.plan(req, cfg.elide, extraSources, usedReport?.path)
            val (code, out) = compileCmds(cmds, resident, inputs, wd)
            if (code == 0) req.jdeps?.let { jdeps ->
                if (usedReport != null && usedReport.exists()) {
                    Jdeps.write(jdeps, req.moduleName ?: "", req.classpath, req.directDependencies, usedReport)
                } else {
                    Jdeps.writeStub(jdeps, req.moduleName ?: "")
                }
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
                    )
                    if (resident == null && merged.resident && merged.elide.isNotEmpty()) {
                        val rec = System.getenv("ELIDE_WORKER_RECORD")?.let { FileOutputStream(it) }
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
