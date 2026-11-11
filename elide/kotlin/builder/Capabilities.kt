package elide.kotlin.builder

/**
 * What the selected Elide's JVM backend reports through `elide javac --capabilities` (shared by kotlinc).
 * `kotlinCompilerPlugins` means `elide kotlinc` loads non-bundled `-Xplugin` jars; without it Elide accepts
 * only its bundled plugins, so compiles with other plugins stay on the stock builder.
 */
data class Capabilities(val kotlinCompilerPlugins: Boolean) {
    companion object {
        val NONE = Capabilities(kotlinCompilerPlugins = false)

        fun parse(json: String): Capabilities =
            Capabilities(kotlinCompilerPlugins = Regex("\"kotlinCompilerPlugins\"\\s*:\\s*true").containsMatchIn(json))

        fun probe(elide: String): Capabilities = try {
            val p = ProcessBuilder(elide, "javac", "--capabilities").redirectErrorStream(true).start()
            val out = p.inputStream.bufferedReader().readText()
            if (p.waitFor() == 0) parse(out) else NONE
        } catch (e: Exception) {
            NONE
        }
    }
}
