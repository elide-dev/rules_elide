package greet;

import java.lang.annotation.ElementType;
import java.lang.annotation.Retention;
import java.lang.annotation.RetentionPolicy;
import java.lang.annotation.Target;

/** Generates `<Type>_Greeting` with a static `greeting()` (see processor.GreetingProcessor). */
@Retention(RetentionPolicy.SOURCE)
@Target(ElementType.TYPE)
public @interface Greet {}
