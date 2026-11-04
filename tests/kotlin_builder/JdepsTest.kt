package elide.kotlin.builder

import com.google.devtools.build.lib.view.proto.Deps
import java.io.File
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertTrue

class JdepsTest {
    @Test fun writesParsableStub() {
        val f = File.createTempFile("jdeps_stub_", ".jdeps")
        Jdeps.writeStub(f.toPath().toString(), ruleLabel = "//pkg:lib")
        val d = Deps.Dependencies.parseFrom(f.readBytes())
        assertEquals("//pkg:lib", d.ruleLabel)
        assertTrue(d.success)
    }

    @Test fun writeClassifiesExplicitImplicitUnused() {
        val report = File.createTempFile("used_", ".txt")
        report.writeText("/cp/a.jar\n/cp/c.jar\n") // a and c were referenced
        val jd = File.createTempFile("real_", ".jdeps")
        try {
            Jdeps.write(
                jd.path,
                ruleLabel = "//pkg:lib",
                classpath = listOf("/cp/a.jar", "/cp/b.jar", "/cp/c.jar"),
                directDeps = listOf("/cp/a.jar", "/cp/b.jar"),
                usedReport = report,
            )
            val d = Deps.Dependencies.parseFrom(jd.readBytes())
            val kind = d.dependencyList.associate { it.path to it.kind }
            assertEquals(Deps.Dependency.Kind.EXPLICIT, kind["/cp/a.jar"], "used + direct -> EXPLICIT")
            assertEquals(Deps.Dependency.Kind.UNUSED, kind["/cp/b.jar"], "direct but unreferenced -> UNUSED")
            assertEquals(Deps.Dependency.Kind.IMPLICIT, kind["/cp/c.jar"], "used transitive -> IMPLICIT")
            assertTrue(d.success)
        } finally {
            report.delete(); jd.delete()
        }
    }
    @Test fun nativeStrictDepsChecksExplicitReferencesOnly() {
        val file = File.createTempFile("native-deps", ".jdeps")
        try {
            val report = Deps.Dependencies.newBuilder().setSuccess(true)
                .addDependency(Deps.Dependency.newBuilder().setPath("direct.jar").setKind(Deps.Dependency.Kind.EXPLICIT))
                .addDependency(Deps.Dependency.newBuilder().setPath("transitive.jar").setKind(Deps.Dependency.Kind.EXPLICIT))
                .addDependency(Deps.Dependency.newBuilder().setPath("implicit.jar").setKind(Deps.Dependency.Kind.IMPLICIT))
                .build()
            file.writeBytes(report.toByteArray())
            val cp = listOf("direct.jar", "transitive.jar", "implicit.jar")
            assertEquals(0, Jdeps.check(file.path, listOf("direct.jar"), cp, "off").first)
            val (code, message) = Jdeps.check(file.path, listOf("direct.jar"), cp, "error")
            assertEquals(1, code)
            assertTrue("transitive.jar" in message)
            assertTrue("implicit.jar" !in message)
            assertEquals(0, Jdeps.check(file.path, listOf("direct.jar"), cp, "warn").first)
            assertEquals(0, Jdeps.check(file.path, cp, cp, "error").first)
        } finally {
            file.delete()
        }
    }
}
