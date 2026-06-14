package elide.kotlin.builder

import com.google.devtools.build.lib.view.proto.Deps
import java.io.File

object Jdeps {
    /** v1 stub: a valid Deps proto, no per-dep classification (strict deps off).
     *  Elide 1.3.1 added `--report-used-deps`, but it currently writes an empty
     *  report (jdeps resource bundle missing in the native image — WHIPLASH
     *  #1002), so we keep the stub. Replace with real used-deps once #1002 is
     *  fixed; original feature request is WHIPLASH #998. */
    fun writeStub(path: String, ruleLabel: String) {
        val deps = Deps.Dependencies.newBuilder()
            .setRuleLabel(ruleLabel)
            .setSuccess(true)
            .build()
        File(path).outputStream().use { deps.writeTo(it) }
    }
}
