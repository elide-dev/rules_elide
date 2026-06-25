package sample;

import org.junit.jupiter.api.Test;
import static org.junit.jupiter.api.Assertions.assertEquals;

public class HelloTest {
  @Test
  void greetsByName() {
    assertEquals("Hello, world!", Hello.greet("world"));
  }
}
