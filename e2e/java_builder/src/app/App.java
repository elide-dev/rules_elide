package app;

import greet.Greet;
import greeter.Greeter;

@Greet
public final class App {
  private App() {}

  public static void main(String[] args) {
    System.out.println(Greeter.greet(args.length > 0 ? args[0] : "Bazel") + ", " + App_Greeting.greeting());
  }
}
