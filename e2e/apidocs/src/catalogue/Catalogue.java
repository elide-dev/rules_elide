package catalogue;

import annotation.Indexed;

/** A catalogue whose public API returns a class that an annotation processor generates. */
@Indexed
public final class Catalogue {
  private Catalogue() {}

  /**
   * Returns the catalogue's index.
   *
   * @return the generated {@link CatalogueIndex}
   */
  public static CatalogueIndex index() {
    return new CatalogueIndex();
  }
}
