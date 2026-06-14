package elide.kotlin.builder

import com.google.devtools.build.lib.view.proto.Deps
import java.io.File

object Jdeps {
    /** v1 stub: a valid Deps proto, no per-dep classification (strict deps off).
     *  Replace with real used-deps once Elide surfaces them (WHIPLASH #998). */
    fun writeStub(path: String, ruleLabel: String) {
        val deps = Deps.Dependencies.newBuilder()
            .setRuleLabel(ruleLabel)
            .setSuccess(true)
            .build()
        File(path).outputStream().use { deps.writeTo(it) }
    }
}
