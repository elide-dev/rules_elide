package elide.java.builder

import java.io.File
import java.util.jar.JarOutputStream

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
}
