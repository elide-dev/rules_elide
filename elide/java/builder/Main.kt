package elide.java.builder

import com.google.devtools.build.lib.worker.WorkerProtocol.Input
import elide.builder.worker.ResidentWorker
import elide.builder.worker.ResidentPool
import elide.builder.worker.WorkerLoop
import java.io.File
import java.nio.file.Files

/**
 * A rules_java JavaBuilder replacement: compiles through `elide javac` when it can reproduce
 * JavaBuilder's outputs, and otherwise delegates to the stock JavaBuilder.
 *
 * Startup flags (injected by the toolchain launcher; Bazel scrubs the worker environment):
 *   --elide=<path> --stock_java=<path> --stock_javabuilder=<jar> --stock_jvm_opt=<opt>…
 *   --error_prone_jar=<jar>… (defaults to the stock JavaBuilder jar, which bundles Error Prone)
 *   --log_routes (prefix each response with the route taken)
 *   --resident_worker (worker mode: forward `elide javac` compiles to warm
 *     `elide javac --persistent_worker` processes instead of starting Elide per compile)
 *   --pass_system (forward JavaBuilder's `--system` to javac; otherwise Elide's embedded JDK class library is used)
 *   --resident_workers=<n> (most resident processes to keep; one is used per concurrent request)
 */
object Main {
    class Config(
        val elide: String,
        val stockJava: String,
        val stockJar: String,
        val stockJvmOpts: List<String>,
        val errorProneJars: List<String>,
        val logRoutes: Boolean,
        val resident: Boolean = false,
        val residentWorkers: Int = 0,
        val passSystem: Boolean = false,
    )

    fun splitConfig(argv: List<String>): Pair<Config, List<String>> {
        var elide = ""; var java = ""; var jar = ""; var log = false; var resident = false; var workers = 0; var system = false
        val opts = mutableListOf<String>(); val ep = mutableListOf<String>(); val rest = mutableListOf<String>()
        for (a in argv) when {
            a.startsWith("--elide=") -> elide = a.substringAfter("=")
            a.startsWith("--stock_java=") -> java = a.substringAfter("=")
            a.startsWith("--stock_javabuilder=") -> jar = a.substringAfter("=")
            a.startsWith("--stock_jvm_opt=") -> opts += a.substringAfter("=")
            a.startsWith("--error_prone_jar=") -> ep += a.substringAfter("=")
            a == "--log_routes" -> log = true
            a == "--resident_worker" -> resident = true
            a == "--pass_system" -> system = true
            a.startsWith("--resident_workers=") -> workers = a.substringAfter("=").toInt()
            else -> rest += a
        }
        return Config(elide, java, jar, opts, ep.ifEmpty { listOf(jar) }, log, resident, workers, system) to rest
    }

    private var caps: Capabilities? = null

    @Synchronized
    private fun capabilities(cfg: Config) = caps ?: Capabilities.probe(cfg.elide).also { caps = it }

    /**
     * Handles one compile; [inputs] is non-null in worker mode (forwarded to the warm stock worker).
     * With a [resident] worker the `elide javac` compile is forwarded to it; if that fails, the
     * compile runs one-shot and the resident process restarts on the next request.
     */
    fun handle(
        cfg: Config,
        args: List<String>,
        stock: Stock,
        inputs: List<Input>?,
        resident: ResidentPool? = null,
    ): Pair<Int, String> {
        val req = Request.parse(args)
        val decision = Router.decide(req, capabilities(cfg))
        val prefix = if (cfg.logRoutes) "[elide-javabuilder] ${decision.route}${if (decision.reason.isEmpty()) "" else ": " + decision.reason}\n" else ""
        if (decision.route == Route.STOCK) {
            val (code, out) = if (inputs != null) stock.forward(args, inputs) else stock.run(args, File("."))
            return code to (prefix + out)
        }
        val srcDir = if (req.sourceJars.isNotEmpty()) Files.createTempDirectory("elide-javabuilder-srcjars").toFile() else null
        val genDir = if (req.generatedSourcesOutput != null) Files.createTempDirectory("elide-javabuilder-gensrc").toFile() else null
        try {
            val extra = srcDir?.let { ElideJavac.extractSourceJars(req.sourceJars, it) }.orEmpty()
            File(req.output).parentFile?.mkdirs()
            val cmd = ElideJavac.plan(req, cfg.elide, cfg.errorProneJars, extra, File.pathSeparator, genDir?.path, cfg.passSystem)
            var note = ""
            val started = System.nanoTime()
            val (code, out) = resident?.let {
                runCatching { it.compile(ElideJavac.workerArgs(cmd), inputs.orEmpty()) }
                    .onFailure { e -> if (cfg.logRoutes) note = "[elide-javabuilder] resident worker failed (${e.message}); compiled one-shot\n" }
                    .getOrNull()
            } ?: ElideJavac.run(cmd, File("."))
            val prefix = prefix + note
            if (code != 0 && req.reduceClasspathMode == "BAZEL_REDUCED") {
                // The failure may only reflect Bazel's reduced classpath. The stock JavaBuilder reports either the
                // real error or the fallback request that makes Bazel retry with the full classpath.
                val (stockCode, stockOut) = if (inputs != null) stock.forward(args, inputs) else stock.run(args, File("."))
                val note = if (cfg.logRoutes) "[elide-javabuilder] STOCK: retrying a reduced-classpath failure\n" else ""
                return stockCode to (prefix + note + stockOut)
            }
            if (code != 0) return code to (prefix + out)
            val compiled = System.nanoTime()
            Outputs.normalizeJar(req.output)
            if (genDir != null) Outputs.writeSourceJar(genDir, req.generatedSourcesOutput!!)
            req.nativeHeaderOutput?.let(Outputs::writeEmptyJar)
            req.manifestProto?.let(Outputs::writeEmptyManifestProto)
            val (depsCode, diagnostic) = StrictDeps.check(req)
            if (diagnostic.isNotEmpty()) {
                // `elide javac --jdeps` marks every jar it loads from as EXPLICIT, including jars reached only
                // through annotations or supertypes, which JavaBuilder accepts (elide-dev/runtime#2987). The
                // report cannot confirm a violation, so the stock JavaBuilder decides and writes the outputs.
                val (stockCode, stockOut) = if (inputs != null) stock.forward(args, inputs) else stock.run(args, File("."))
                val note = if (cfg.logRoutes) "[elide-javabuilder] STOCK: confirming a possible strict-deps violation\n" else ""
                return stockCode to (prefix + note + stockOut)
            }
            val timing = if (cfg.logRoutes) {
                val done = System.nanoTime()
                "[elide-javabuilder] timing: compile ${(compiled - started) / 1_000_000} ms, outputs and deps ${(done - compiled) / 1_000_000} ms\n"
            } else {
                ""
            }
            return depsCode to (prefix + timing + out + diagnostic)
        } finally {
            srcDir?.deleteRecursively()
            genDir?.deleteRecursively()
        }
    }

    @JvmStatic
    fun main(argv: Array<String>) {
        val (cfg, rest) = splitConfig(argv.toList())
        Stock(cfg.stockJava, cfg.stockJar, cfg.stockJvmOpts).use { stock ->
            if (rest.contains("--persistent_worker")) {
                // Singleplex requests are handled serially, multiplex requests concurrently.
                val resident = if (cfg.resident) {
                    ResidentPool(cfg.residentWorkers.takeIf { it > 0 } ?: ResidentPool.defaultSize()) { ResidentWorker(cfg.elide, "javac") }
                } else {
                    null
                }
                try {
                    WorkerLoop.serve(System.`in`, System.out) { request ->
                        handle(cfg, request.argumentsList, stock, request.inputsList, resident)
                    }
                } finally {
                    resident?.close()
                }
            } else {
                val (code, out) = handle(cfg, rest, stock, null)
                if (out.isNotEmpty()) System.err.print(out)
                kotlin.system.exitProcess(code)
            }
        }
    }
}
