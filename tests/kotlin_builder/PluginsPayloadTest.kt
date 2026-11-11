package elide.kotlin.builder

import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertTrue

class PluginsPayloadTest {
    @Test fun parsesRulesKotlinPayload() {
        val json = """{"plugins":[{"classpath":["a/compose.jar","b/x.jar"],"id":"androidx.compose.compiler.plugins.kotlin","options":[],"phases":["PLUGIN_PHASE_COMPILE","PLUGIN_PHASE_STUBS"]},{"classpath":[],"id":"pé","options":[{"id":"k","value":"v \"q\""}],"phases":[]}]}"""
        val plugins = PluginsPayload.parse(json)
        assertEquals(2, plugins.size)
        assertEquals("androidx.compose.compiler.plugins.kotlin", plugins[0].id)
        assertEquals(listOf("a/compose.jar", "b/x.jar"), plugins[0].classpath)
        assertTrue(plugins[0].compiles && plugins[0].stubs)
        assertEquals("pé", plugins[1].id)
        assertEquals(mapOf("id" to "k", "value" to "v \"q\""), plugins[1].options.single())
        assertTrue(plugins[1].compiles)
    }

    @Test fun readsTheFlagfileToken() {
        val token = """'{"plugins":[{"classpath":["c.jar"],"id":"i","options":[],"phases":["PLUGIN_PHASE_COMPILE"]}]}'"""
        val req = Flagfile.parse(listOf("--sources", "A.kt", "--plugins_payload", token))
        assertEquals(listOf("c.jar"), req.payloadPlugins.single().classpath)
    }
}
