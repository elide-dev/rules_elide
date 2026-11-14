package elide.kotlin.builder

/**
 * rules_kotlin (2.4+) delivers compiler plugins as `--plugins_payload <json>`:
 * `{"plugins":[{"id":…,"classpath":[…],"options":[…],"phases":["PLUGIN_PHASE_COMPILE",…]}]}`,
 * instead of `--compiler_plugin_classpath`/`--compiler_plugin_options`.
 */
data class PayloadPlugin(
    val id: String,
    val classpath: List<String>,
    val options: List<Any?>,
    val phases: List<String>,
) {
    /** Plugins without phases apply to the compile, as rules_kotlin treats them. */
    val compiles: Boolean get() = phases.isEmpty() || "PLUGIN_PHASE_COMPILE" in phases
    val stubs: Boolean get() = "PLUGIN_PHASE_STUBS" in phases
}

object PluginsPayload {
    fun parse(json: String): List<PayloadPlugin> {
        val text = if (json.length >= 2 && json.startsWith("'") && json.endsWith("'")) json.substring(1, json.length - 1) else json
        val root = Json(text).value() as? Map<*, *> ?: return emptyList()
        val plugins = root["plugins"] as? List<*> ?: return emptyList()
        return plugins.mapNotNull { p ->
            val m = p as? Map<*, *> ?: return@mapNotNull null
            PayloadPlugin(
                id = m["id"] as? String ?: "",
                classpath = (m["classpath"] as? List<*>).orEmpty().filterIsInstance<String>(),
                options = (m["options"] as? List<*>).orEmpty(),
                phases = (m["phases"] as? List<*>).orEmpty().filterIsInstance<String>(),
            )
        }
    }

    /** Minimal JSON reader for the payload: objects, arrays, strings, numbers, booleans and null. */
    private class Json(private val s: String) {
        private var i = 0

        fun value(): Any? {
            ws()
            return when (s[i]) {
                '{' -> obj()
                '[' -> arr()
                '"' -> str()
                't' -> lit("true", true)
                'f' -> lit("false", false)
                'n' -> lit("null", null)
                else -> num()
            }
        }

        private fun ws() { while (i < s.length && s[i].isWhitespace()) i++ }

        private fun lit(word: String, v: Any?): Any? {
            require(s.startsWith(word, i)) { "bad JSON literal at $i" }
            i += word.length
            return v
        }

        private fun num(): Any {
            val start = i
            while (i < s.length && (s[i].isDigit() || s[i] in "+-.eE")) i++
            return s.substring(start, i).toDouble()
        }

        private fun str(): String {
            i++ // opening quote
            val sb = StringBuilder()
            while (s[i] != '"') {
                val c = s[i++]
                if (c != '\\') { sb.append(c); continue }
                when (val e = s[i++]) {
                    'n' -> sb.append('\n'); 't' -> sb.append('\t'); 'r' -> sb.append('\r')
                    'b' -> sb.append('\b'); 'f' -> sb.append('\u000c')
                    'u' -> { sb.append(s.substring(i, i + 4).toInt(16).toChar()); i += 4 }
                    else -> sb.append(e)
                }
            }
            i++ // closing quote
            return sb.toString()
        }

        private fun arr(): List<Any?> {
            i++
            val out = mutableListOf<Any?>()
            ws()
            if (s[i] == ']') { i++; return out }
            while (true) {
                out += value(); ws()
                if (s[i++] == ']') return out
            }
        }

        private fun obj(): Map<String, Any?> {
            i++
            val out = LinkedHashMap<String, Any?>()
            ws()
            if (s[i] == '}') { i++; return out }
            while (true) {
                ws(); val k = str(); ws()
                require(s[i++] == ':') { "expected ':' at ${i - 1}" }
                out[k] = value(); ws()
                if (s[i++] == '}') return out
            }
        }
    }
}
