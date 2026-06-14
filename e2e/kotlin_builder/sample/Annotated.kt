package sample

import proc.Marker
import proc.gen.AnnotatedGenerated

@Marker
class Annotated {
    // References the KAPT-generated class, so the post-KAPT Elide fast-path
    // compile must resolve it from --source_jars (regression for rules_elide #6).
    fun name(): String = AnnotatedGenerated.marker()
}
