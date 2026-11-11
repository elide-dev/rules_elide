package elide.java.builder

import java.io.File
import java.nio.file.Files
import java.util.zip.ZipEntry
import java.util.zip.ZipFile
import java.util.zip.ZipOutputStream
import kotlin.test.Test
import kotlin.test.assertContentEquals
import kotlin.test.assertEquals

class OutputsTest {
    private fun jar(file: File, time: Long) {
        ZipOutputStream(file.outputStream()).use { out ->
            out.putNextEntry(ZipEntry("META-INF/").apply { this.time = time }); out.closeEntry()
            out.putNextEntry(ZipEntry("a/A.class").apply { this.time = time }); out.write(byteArrayOf(1, 2, 3)); out.closeEntry()
        }
    }

    @Test fun normalizedJarsAreByteIdentical() {
        val dir = Files.createTempDirectory("outputs").toFile()
        val a = File(dir, "a.jar").also { jar(it, 1_700_000_000_000) }
        val b = File(dir, "b.jar").also { jar(it, 1_800_000_000_000) }
        Outputs.normalizeJar(a.path)
        Outputs.normalizeJar(b.path)
        assertContentEquals(a.readBytes(), b.readBytes())
        ZipFile(a).use { zip ->
            assertEquals(listOf("META-INF/", "a/A.class"), zip.entries().toList().map { it.name })
            assertContentEquals(byteArrayOf(1, 2, 3), zip.getInputStream(zip.getEntry("a/A.class")).readBytes())
            assertEquals(2010, zip.getEntry("a/A.class").timeLocal.year)
        }
    }
}
