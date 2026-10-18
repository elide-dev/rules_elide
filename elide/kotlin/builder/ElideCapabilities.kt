package elide.kotlin.builder

import java.io.File
import java.util.concurrent.ConcurrentHashMap

/** Optional `elide kotlinc` flags, probed once per Elide binary from its `--help`. */
object ElideCapabilities {
    private val jdeps = ConcurrentHashMap<String, Boolean>()
    private val kapt = ConcurrentHashMap<String, Boolean>()
    private val ksp = ConcurrentHashMap<String, Boolean>()

    /** Whether `elide kotlinc` runs annotation processors itself (`--kapt-sources`). */
    fun supportsKapt(elide: String): Boolean = kapt.getOrPut(elide) { helpMentions(elide, "--kapt-sources") }

    /** Whether `elide kotlinc` runs KSP2 processors itself (`--ksp-sources`). */
    fun supportsKsp(elide: String): Boolean = ksp.getOrPut(elide) { helpMentions(elide, "--ksp-sources") }

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
