package elide.java.builder

import java.io.File
import java.time.LocalDateTime
import java.util.jar.JarOutputStream
import java.util.zip.ZipEntry
import java.util.zip.ZipFile
import java.util.zip.ZipOutputStream

/** Declared JavaBuilder outputs that the Elide path does not produce itself. */
object Outputs {
    /** An empty jar: the request's sources declare no native methods (Router checks). */
    fun writeEmptyJar(path: String) {
        File(path).parentFile?.mkdirs()
        JarOutputStream(File(path).outputStream()).use { }
    }

    /** An empty `blaze.buildjar.Manifest`: valid protobuf with no compilation units. */
    fun writeEmptyManifestProto(path: String) {
        File(path).parentFile?.mkdirs()
        File(path).writeBytes(ByteArray(0))
    }

    /** JavaBuilder's (and singlejar's) normalized entry time, so outputs are byte-identical across runs. */
    private val NORMALIZED_TIME: LocalDateTime = LocalDateTime.of(2010, 1, 1, 0, 0)

    /**
     * Rewrites [path] with fixed entry timestamps and no extra fields, keeping entry order and contents.
     * `elide javac --jar` stamps entries with the wall clock, so identical compiles otherwise differ.
     */
    fun normalizeJar(path: String) {
        val source = File(path)
        val temp = File(source.parentFile, source.name + ".normalizing")
        ZipFile(source).use { zip ->
            ZipOutputStream(temp.outputStream().buffered()).use { out ->
                for (entry in zip.entries()) {
                    val copy = ZipEntry(entry.name)
                    copy.timeLocal = NORMALIZED_TIME
                    out.putNextEntry(copy)
                    if (!entry.isDirectory) zip.getInputStream(entry).use { it.copyTo(out) }
                    out.closeEntry()
                }
            }
        }
        if (!temp.renameTo(source)) {
            temp.copyTo(source, overwrite = true)
            temp.delete()
        }
    }

    /** Packs the files under [dir] into a source jar at [path], sorted and with normalized timestamps. */
    fun writeSourceJar(dir: File, path: String) {
        File(path).parentFile?.mkdirs()
        ZipOutputStream(File(path).outputStream().buffered()).use { out ->
            dir.walkTopDown().filter { it.isFile }.map { it.relativeTo(dir).invariantSeparatorsPath }.sorted().forEach { name ->
                out.putNextEntry(ZipEntry(name).apply { timeLocal = NORMALIZED_TIME })
                File(dir, name).inputStream().use { it.copyTo(out) }
                out.closeEntry()
            }
        }
    }
}
