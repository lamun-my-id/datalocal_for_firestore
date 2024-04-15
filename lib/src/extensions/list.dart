extension ListExtension on List {
  /// Part Extension of [List] used to filter data with operator containAny
  bool containAny(List value) {
    bool result = false;
    for (var val in this) {
      if (value.contains(val)) {
        result = true;
      }
    }
    return result;
  }

  /// Part Extension of [List] to chunk list size
  List<List> chunks(int size) {
    var chunks = (length / size).ceil();
    return List.generate(chunks, (i) => skip(i * size).take(size).toList());
  }
}
