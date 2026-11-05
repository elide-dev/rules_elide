package sample

import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Test

class KotlinTest {
  @Test
  fun greetsThroughKotlinAndJava() {
    assertEquals("Hello, remote IC!", Greeter.greet("remote IC"))
  }
}
