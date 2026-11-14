package stability;

import java.lang.annotation.Retention;
import java.lang.annotation.RetentionPolicy;

/**
 * Marks API stability, like JUnit's `@API(status = …)`: consumers of an annotated class never name it, but the
 * compiler loads it to resolve the enum value.
 */
@Retention(RetentionPolicy.RUNTIME)
public @interface Stable {
  Level level() default Level.STABLE;

  enum Level {
    STABLE,
    EVOLVING
  }
}
