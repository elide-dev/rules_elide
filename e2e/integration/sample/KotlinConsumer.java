package sample;

public final class KotlinConsumer {
  public static void main(String[] args) {
    if (KotlinInterop.value() != 3) {
      throw new AssertionError("Incorrect Kotlin library result");
    }
    System.out.println("kotlin-interop-ok");
  }
}
