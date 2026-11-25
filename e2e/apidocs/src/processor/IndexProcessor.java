package processor;

import java.io.IOException;
import java.io.Writer;
import java.util.Set;
import javax.annotation.processing.AbstractProcessor;
import javax.annotation.processing.RoundEnvironment;
import javax.annotation.processing.SupportedAnnotationTypes;
import javax.lang.model.SourceVersion;
import javax.lang.model.element.Element;
import javax.lang.model.element.PackageElement;
import javax.lang.model.element.TypeElement;

/** Writes a {@code <Type>Index} class for each type annotated with {@code @Indexed}. */
@SupportedAnnotationTypes("annotation.Indexed")
public final class IndexProcessor extends AbstractProcessor {
  @Override
  public SourceVersion getSupportedSourceVersion() {
    return SourceVersion.latestSupported();
  }

  @Override
  public boolean process(Set<? extends TypeElement> annotations, RoundEnvironment round) {
    for (TypeElement annotation : annotations) {
      for (Element element : round.getElementsAnnotatedWith(annotation)) {
        String pkg = ((PackageElement) element.getEnclosingElement()).getQualifiedName().toString();
        String name = element.getSimpleName() + "Index";
        try (Writer out = processingEnv.getFiler().createSourceFile(pkg + "." + name, element).openWriter()) {
          out.write("package " + pkg + ";\n\n"
              + "/** The generated index of {@link " + element.getSimpleName() + "}. */\n"
              + "public final class " + name + " {\n"
              + "  /** Creates the index. */\n"
              + "  public " + name + "() {}\n\n"
              + "  /**\n   * The number of entries.\n   *\n   * @return always one\n   */\n"
              + "  public int size() {\n    return 1;\n  }\n}\n");
        } catch (IOException e) {
          throw new IllegalStateException(e);
        }
      }
    }
    return true;
  }
}
