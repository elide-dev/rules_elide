package app;

import greeter.Greeter;

public final class App {
  private App() {}

  public static void main(String[] args) {
    System.out.println(Greeter.greet(args.length > 0 ? args[0] : "Bazel"));
  }
}
