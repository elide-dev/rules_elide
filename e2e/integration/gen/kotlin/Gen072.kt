package gen

// Generated benchmark fixture — do not edit by hand (see e2e/gen_fixture.py).
object Gen072 {
  fun transform(xs: List<Int>): Map<String, List<Int>> =
    xs.groupBy { "bucket${it % 5}" }.mapValues { (_, v) -> v.sorted() }

  fun pipeline(n: Int): List<Pair<Int, String>> =
    (0 until n).map { it to "v072_$it" }.filter { it.first % 2 == 0 }

  fun reduce(items: List<Pair<String, Int>>): Map<String, Int> =
    items.fold(mutableMapOf<String, Int>()) { acc, (k, v) -> acc.apply { merge(k, v, Int::plus) } }

  fun seed(): List<Int> = generateSequence(72) { it + 1 }.take(10).toList()
}
