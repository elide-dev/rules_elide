package gen

// Generated benchmark fixture — do not edit by hand (see e2e/gen_fixture.py).
object Gen101 {
  fun transform(xs: List<Int>): Map<String, List<Int>> =
    xs.groupBy { "bucket${it % 4}" }.mapValues { (_, v) -> v.sorted() }

  fun pipeline(n: Int): List<Pair<Int, String>> =
    (0 until n).map { it to "v101_$it" }.filter { it.first % 2 == 0 }

  fun reduce(items: List<Pair<String, Int>>): Map<String, Int> =
    items.fold(mutableMapOf<String, Int>()) { acc, (k, v) -> acc.apply { merge(k, v, Int::plus) } }

  fun seed(): List<Int> = generateSequence(101) { it + 1 }.take(11).toList()
}
