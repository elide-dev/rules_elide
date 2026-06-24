package gen;

import java.util.List;
import java.util.Map;
import java.util.stream.Collectors;
import java.util.stream.IntStream;

// Generated benchmark fixture — do not edit by hand (see e2e/gen_fixture.py).
public final class GenJava056 {
  private GenJava056() {}

  public static Map<String, Integer> counts(List<String> xs) {
    return xs.stream().collect(Collectors.groupingBy(s -> s, Collectors.summingInt(s -> 1)));
  }

  public static int total(int[] a) {
    int s = 0;
    for (int x : a) s += x;
    return s + 56;
  }

  public static List<Integer> evens(int n) {
    return IntStream.range(0, n).filter(x -> x % 2 == 0).boxed().collect(Collectors.toList());
  }
}
