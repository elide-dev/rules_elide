package elide.kotlin.builder

import java.nio.file.Files
import kotlin.test.Test
import kotlin.test.assertEquals

class FallbackTest {
    @Test fun passesFlagfileVerbatim() {
        // Pre-23 JDK: no Unsafe silencer, command is the stock builder + flagfile.
        assertEquals(
            listOf("/bin/stock", "--flagfile=/tmp/f"),
            Fallback.command(stockBuilder = "/bin/stock", flagfile = "/tmp/f", jdkFeature = 21),
        )
    }

    @Test fun silencesUnsafeWarningOnJdk23Plus() {
        // JDK 23+: inject the kapt Unsafe-deprecation silencer (WHIPLASH#1131),
        // routed through the java_binary stub's --wrapper_script_flag passthrough.
        assertEquals(
            listOf(
                "/bin/stock",
                "--wrapper_script_flag=--jvm_flag=--sun-misc-unsafe-memory-access=allow",
                "--flagfile=/tmp/f",
            ),
            Fallback.command(stockBuilder = "/bin/stock", flagfile = "/tmp/f", jdkFeature = 23),
        )
    }

    @Test fun readsFeatureVersionFromJavaHome() {
        val home = Files.createTempDirectory("jdk").toFile()
        try {
            assertEquals(0, Fallback.jdkFeature(home.path))
            home.resolve("release").writeText("IMPLEMENTOR=\"x\"\nJAVA_VERSION=\"21.0.5\"\n")
            assertEquals(21, Fallback.jdkFeature(home.path))
            home.resolve("release").writeText("JAVA_VERSION=\"25\"\n")
            assertEquals(25, Fallback.jdkFeature(home.path))
            assertEquals(0, Fallback.jdkFeature(null))
        } finally {
            home.deleteRecursively()
        }
    }
}
