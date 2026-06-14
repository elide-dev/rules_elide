package proc;

import java.lang.annotation.ElementType;
import java.lang.annotation.Retention;
import java.lang.annotation.RetentionPolicy;
import java.lang.annotation.Target;

/** Trivial marker annotation consumed by {@link MarkerProcessor}. */
@Retention(RetentionPolicy.SOURCE)
@Target(ElementType.TYPE)
public @interface Marker {}
