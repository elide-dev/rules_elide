package elide.java.builder

import com.google.devtools.build.lib.view.proto.Deps
import java.io.File
import java.nio.file.Files
import java.util.jar.Attributes
import java.util.jar.JarOutputStream
import java.util.jar.Manifest
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertTrue

class StrictDepsTest {
    private val dir = Files.createTempDirectory("strict").toFile()

    private fun ijar(name: String, label: String): String {
        val manifest = Manifest().apply {
            mainAttributes[Attributes.Name.MANIFEST_VERSION] = "1.0"
            mainAttributes.putValue("Target-Label", label)
        }
        val f = File(dir, name)
        JarOutputStream(f.outputStream(), manifest).use { }
        return f.path
    }

    private fun jdeps(vararg explicit: String): String {
        val f = File(dir, "out.jdeps")
        val deps = Deps.Dependencies.newBuilder().setSuccess(true)
        explicit.forEach { deps.addDependency(Deps.Dependency.newBuilder().setPath(it).setKind(Deps.Dependency.Kind.EXPLICIT)) }
        f.outputStream().use { deps.build().writeTo(it) }
        return f.path
    }

    private fun req(depsProto: String, mode: String, direct: String, transitive: String) = Request.parse(listOf(
        "--output", "a.jar", "--output_deps_proto", depsProto, "--target_label", "//a:b", "--strict_java_deps", mode,
        "--direct_dependencies", direct, "--classpath", direct, transitive,
    ))

    @Test fun indirectExplicitUseIsAnError() {
        val direct = ijar("direct.jar", "//a:direct")
        val transitive = ijar("transitive.jar", "//a:transitive")
        val (code, message) = StrictDeps.check(req(jdeps(direct, transitive), "ERROR", direct, transitive))
        assertEquals(1, code)
        assertTrue("//a:transitive" in message && "buildozer 'add deps //a:transitive' //a:b" in message, message)
    }

    @Test fun warnAndOffDoNotFail() {
        val direct = ijar("direct.jar", "//a:direct")
        val transitive = ijar("transitive.jar", "//a:transitive")
        assertEquals(0, StrictDeps.check(req(jdeps(transitive), "WARN", direct, transitive)).first)
        assertEquals(0 to "", StrictDeps.check(req(jdeps(transitive), "OFF", direct, transitive)))
        assertEquals(0 to "", StrictDeps.check(req(jdeps(direct), "ERROR", direct, transitive)))
    }
}
