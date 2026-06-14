package elide.kotlin.builder

import java.io.File
import java.nio.file.Paths

object Main {
    class Config(val elide: String, val fallback: String)

    fun splitConfig(argv: List<String>): Pair<Config, List<String>> {
        var elide = ""; var fallback = ""; val rest = mutableListOf<String>()
        for (a in argv) when {
            a.startsWith("--elide=") -> elide = a.substringAfter("=")
            a.startsWith("--fallback_builder=") -> fallback = a.substringAfter("=")
            else -> rest += a
        }
        return Config(elide, fallback) to rest
    }

    /** Handle one unit of work. Returns (exitCode, capturedOutput). */
    internal fun handle(cfg: Config, rest: List<String>): Pair<Int, String> {
        val ff = rest.first { it.startsWith("--flagfile=") }.substringAfter("=")
        val req = Flagfile.parse(Flagfile.readTokens(Paths.get(ff)))
        val wd = File(".")
        if (Router.route(req).route == Route.FALLBACK) return Fallback.run(cfg.fallback, ff, wd)
        val code = ElideCompile.run(ElideCompile.plan(req, cfg.elide), wd)
        if (code == 0) req.jdeps?.let { Jdeps.writeStub(it, req.moduleName ?: "") }
        return code to ""
    }

    @JvmStatic
    fun main(argv: Array<String>) {
        val (cfg, rest) = splitConfig(argv.toList())
        if (rest.contains("--persistent_worker")) {
            val stdin = System.`in`; val stdout = System.out
            while (true) {
                val wr = Worker.readRequest(stdin) ?: break
                val (cfg2, r) = splitConfig(wr.argumentsList)
                val merged = Config(cfg2.elide.ifEmpty { cfg.elide }, cfg2.fallback.ifEmpty { cfg.fallback })
                val (code, out) = runCatching { handle(merged, r) }.getOrElse { 1 to (it.message ?: "error") }
                Worker.writeResponse(stdout, code, out, wr.requestId)
            }
        } else {
            val (code, out) = handle(cfg, rest)
            if (out.isNotEmpty()) System.err.print(out)
            kotlin.system.exitProcess(code)
        }
    }
}
