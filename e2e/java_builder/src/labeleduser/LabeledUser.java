package labeleduser;

import labeled.Labeled;

/**
 * Uses `Labeled` without naming its `@Stable` annotation, whose jar is only an indirect dependency, so the
 * shim confirms strict deps on the stock JavaBuilder. The ignored `trim()` result is something Error Prone's
 * default checks reject and `elide javac` accepts: the toolchain has no Error Prone options, so both must accept.
 */
public final class LabeledUser {
  private LabeledUser() {}

  public static String label() {
    String label = Labeled.label();
    label.trim();
    return label;
  }
}
