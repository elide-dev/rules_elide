package elide.kotlin.builder

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

    @Test fun parsesJavaFeatureVersions() {
        assertEquals(11, Fallback.parseJavaFeature("openjdk version \"11.0.22\" 2024-01-16"))
        assertEquals(8, Fallback.parseJavaFeature("openjdk version \"1.8.0_402\""))
        assertEquals(25, Fallback.parseJavaFeature("openjdk version \"25\" 2025-09-16"))
        assertEquals(0, Fallback.parseJavaFeature("garbage"))
    }
}
