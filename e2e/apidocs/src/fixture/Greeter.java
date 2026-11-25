package fixture;

/// Greets people by name.
///
/// This is a Markdown documentation comment: it has `code`, **emphasis** and a list.
///
/// - [#greet()] returns the greeting.
/// - [Object#toString()] is overridden too.
public class Greeter {
  private final String name;

  /**
   * Creates a greeter.
   *
   * @param name who to greet
   */
  public Greeter(String name) {
    this.name = name;
  }

  /// Returns the greeting.
  ///
  /// @return `Hello, ` followed by the name
  public String greet() {
    return "Hello, " + name;
  }

  /** {@inheritDoc} */
  @Override
  public String toString() {
    return "Greeter[" + name + "]";
  }
}
