package annotation;

import java.lang.annotation.ElementType;
import java.lang.annotation.Retention;
import java.lang.annotation.RetentionPolicy;
import java.lang.annotation.Target;

/** Generates a {@code <Type>Index} class next to the annotated type. */
@Retention(RetentionPolicy.SOURCE)
@Target(ElementType.TYPE)
public @interface Indexed {}
