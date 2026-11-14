package labeled;

import stability.Stable;

@Stable(level = Stable.Level.EVOLVING)
public final class Labeled {
  private Labeled() {}

  public static String label() {
    return "labeled";
  }
}
