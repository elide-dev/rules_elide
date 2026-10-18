package elide.kotlin.builder

import java.io.File
import java.util.concurrent.ConcurrentHashMap

/** Optional `elide kotlinc` flags, probed once per Elide binary from its `--help`. */
object ElideCapabilities {
    private val jdeps = ConcurrentHashMap<String, Boolean>()

    /** Whether `elide kotlinc` writes `.jdeps` itself (`--jdeps`). */
    fun supportsJdeps(elide: String): Boolean = jdeps.getOrPut(elide) { helpMentions(elide, "--jdeps") }

    internal fun helpMentions(elide: String, flag: String): Boolean = runCatching {
        val out = File.createTempFile("elide-help", ".txt")
        try {
            val p = ProcessBuilder(elide, "kotlinc", "--help")
                .redirectErrorStream(true)
                .redirectOutput(out)
                .start()
            p.waitFor() == 0 && out.readText().contains(flag)
        } finally {
            out.delete()
        }
    }.getOrDefault(false)
}
