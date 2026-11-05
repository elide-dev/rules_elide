package sample

object KotlinInterop {
    @JvmStatic fun value(): Int = listOf(1, 2).sum()
    @JvmStatic fun main(args: Array<String>) {
        check(value() == 3)
        println("kotlin-interop-ok")
    }
}
