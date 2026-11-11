package elide.java.builder

import com.google.devtools.build.lib.worker.WorkerProtocol.Input
import com.google.devtools.build.lib.worker.WorkerProtocol.WorkRequest
import com.google.devtools.build.lib.worker.WorkerProtocol.WorkResponse
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
 */
object Main {
    class Config(
        val elide: String,
        val stockJava: String,
        val stockJar: String,
        val stockJvmOpts: List<String>,
        val errorProneJars: List<String>,
        val logRoutes: Boolean,
    )

    fun splitConfig(argv: List<String>): Pair<Config, List<String>> {
        var elide = ""; var java = ""; var jar = ""; var log = false
        val opts = mutableListOf<String>(); val ep = mutableListOf<String>(); val rest = mutableListOf<String>()
        for (a in argv) when {
            a.startsWith("--elide=") -> elide = a.substringAfter("=")
            a.startsWith("--stock_java=") -> java = a.substringAfter("=")
            a.startsWith("--stock_javabuilder=") -> jar = a.substringAfter("=")
            a.startsWith("--stock_jvm_opt=") -> opts += a.substringAfter("=")
            a.startsWith("--error_prone_jar=") -> ep += a.substringAfter("=")
            a == "--log_routes" -> log = true
            else -> rest += a
        }
        return Config(elide, java, jar, opts, ep.ifEmpty { listOf(jar) }, log) to rest
    }

    private var caps: Capabilities? = null

    private fun capabilities(cfg: Config) = caps ?: Capabilities.probe(cfg.elide).also { caps = it }

    /** Handles one compile; [inputs] is non-null in worker mode (forwarded to the warm stock worker). */
    fun handle(cfg: Config, args: List<String>, stock: Stock, inputs: List<Input>?): Pair<Int, String> {
        val req = Request.parse(args)
        val decision = Router.decide(req, capabilities(cfg))
        val prefix = if (cfg.logRoutes) "[elide-javabuilder] ${decision.route}${if (decision.reason.isEmpty()) "" else ": " + decision.reason}\n" else ""
        if (decision.route == Route.STOCK) {
            val (code, out) = if (inputs != null) stock.forward(args, inputs) else stock.run(args, File("."))
            return code to (prefix + out)
        }
        val srcDir = if (req.sourceJars.isNotEmpty()) Files.createTempDirectory("elide-javabuilder-srcjars").toFile() else null
        try {
            val extra = srcDir?.let { ElideJavac.extractSourceJars(req.sourceJars, it) }.orEmpty()
            File(req.output).parentFile?.mkdirs()
            val cmd = ElideJavac.plan(req, cfg.elide, cfg.errorProneJars, extra, File.pathSeparator)
            val (code, out) = ElideJavac.run(cmd, File("."))
            if (code != 0 && req.reduceClasspathMode == "BAZEL_REDUCED") {
                // The failure may only reflect Bazel's reduced classpath. The stock JavaBuilder reports either the
                // real error or the fallback request that makes Bazel retry with the full classpath.
                val (stockCode, stockOut) = if (inputs != null) stock.forward(args, inputs) else stock.run(args, File("."))
                val note = if (cfg.logRoutes) "[elide-javabuilder] STOCK: retrying a reduced-classpath failure\n" else ""
                return stockCode to (prefix + note + stockOut)
            }
            if (code != 0) return code to (prefix + out)
            Outputs.normalizeJar(req.output)
            req.nativeHeaderOutput?.let(Outputs::writeEmptyJar)
            req.manifestProto?.let(Outputs::writeEmptyManifestProto)
            val (depsCode, diagnostic) = StrictDeps.check(req)
            return depsCode to (prefix + out + diagnostic)
        } finally {
            srcDir?.deleteRecursively()
        }
    }

    @JvmStatic
    fun main(argv: Array<String>) {
        val (cfg, rest) = splitConfig(argv.toList())
        Stock(cfg.stockJava, cfg.stockJar, cfg.stockJvmOpts).use { stock ->
            if (rest.contains("--persistent_worker")) {
                // Singleplex: requests are handled serially (the toolchain disables multiplex workers).
                while (true) {
                    val request = WorkRequest.parseDelimitedFrom(System.`in`) ?: break
                    val (code, out) = runCatching { handle(cfg, request.argumentsList, stock, request.inputsList) }
                        .getOrElse { 1 to (it.stackTraceToString()) }
                    WorkResponse.newBuilder().setExitCode(code).setOutput(out).setRequestId(request.requestId).build()
                        .writeDelimitedTo(System.out)
                    System.out.flush()
                }
            } else {
                val (code, out) = handle(cfg, rest, stock, null)
                if (out.isNotEmpty()) System.err.print(out)
                kotlin.system.exitProcess(code)
            }
        }
    }
}
