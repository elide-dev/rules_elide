package proc;

import java.io.IOException;
import java.io.Writer;
import java.util.Set;
import javax.annotation.processing.AbstractProcessor;
import javax.annotation.processing.RoundEnvironment;
import javax.annotation.processing.SupportedAnnotationTypes;
import javax.annotation.processing.SupportedSourceVersion;
import javax.lang.model.SourceVersion;
import javax.lang.model.element.Element;
import javax.lang.model.element.TypeElement;
import javax.tools.JavaFileObject;

/**
 * Trivial annotation processor: for each {@code @Marker}-annotated type it
 * generates a `<Name>Generated` Java class. Its presence forces rules_kotlin to
 * pass {@code --processors}/{@code --processorpath} in the KotlinBuilder
 * flagfile, which the Elide shim's Router detects and delegates to the stock
 * builder (KAPT is not on the Elide fast path).
 */
@SupportedAnnotationTypes("proc.Marker")
@SupportedSourceVersion(SourceVersion.RELEASE_8)
public final class MarkerProcessor extends AbstractProcessor {
  @Override
  public boolean process(Set<? extends TypeElement> annotations, RoundEnvironment roundEnv) {
    for (Element e : roundEnv.getElementsAnnotatedWith(processingEnv.getElementUtils().getTypeElement("proc.Marker"))) {
      String simple = e.getSimpleName().toString();
      String genName = simple + "Generated";
      try {
        JavaFileObject f = processingEnv.getFiler().createSourceFile("proc.gen." + genName);
        try (Writer w = f.openWriter()) {
          w.write("package proc.gen;\n");
          w.write("public final class " + genName + " {\n");
          w.write("  public static String marker() { return \"" + simple + "\"; }\n");
          w.write("}\n");
        }
      } catch (IOException ex) {
        throw new RuntimeException(ex);
      }
    }
    return true;
  }
}
