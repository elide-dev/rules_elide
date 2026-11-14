package elide.java.builder

/** What the selected `elide javac` reports through `--capabilities`. */
data class Capabilities(val annotationProcessing: Boolean, val javacPlugins: Boolean) {
    companion object {
        val NONE = Capabilities(annotationProcessing = false, javacPlugins = false)

        fun parse(json: String): Capabilities = Capabilities(
            annotationProcessing = flag(json, "javaAnnotationProcessing"),
            javacPlugins = flag(json, "javacPlugins"),
        )

        private fun flag(json: String, key: String): Boolean =
            Regex("\"" + Regex.escape(key) + "\"\\s*:\\s*true").containsMatchIn(json)

        fun probe(elide: String): Capabilities = try {
            val p = ProcessBuilder(elide, "javac", "--capabilities").redirectErrorStream(true).start()
            val out = p.inputStream.bufferedReader().readText()
            if (p.waitFor() == 0) parse(out) else NONE
        } catch (e: Exception) {
            NONE
        }
    }
}
