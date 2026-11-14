package labeleduser;

import labeled.Labeled;

/** Uses `Labeled` without naming its `@Stable` annotation, whose jar is only an indirect dependency. */
public final class LabeledUser {
  private LabeledUser() {}

  public static String label() {
    return Labeled.label();
  }
}
