package sample

import org.junit.jupiter.api.Test
import org.junit.jupiter.api.Assertions.assertEquals

class GreeterTest {
  @Test
  fun greets() {
    assertEquals("Hello, kt!", Greeter.greet("kt"))
  }
}
