package fixture.archive.paths.exceed.one.hundred.bytes;

/** Its page path is longer than a tar header's 100-byte name field. */
public interface AnInterfaceWhoseNameIsLongEnoughThatItsPagePathNeedsAPaxHeader {
  /**
   * Returns a value.
   *
   * @return a value
   */
  int value();
}
