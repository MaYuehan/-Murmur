class ListSortOrder {
  ListSortOrder._();

  static int defaultFromCreatedAt(DateTime createdAt) {
    return createdAt.microsecondsSinceEpoch ~/ 1000;
  }

  static int defaultNow() {
    return defaultFromCreatedAt(DateTime.now());
  }

  static int betweenOrdered(int before, int after) {
    if (after > before) {
      final int gap = after - before;
      if (gap > 1) {
        return before + (gap ~/ 2);
      }
    }
    return before + 1000;
  }

  static int afterLast(int last) {
    return last + 1000;
  }

  static int beforeFirst(int first) {
    if (first > 1) {
      return betweenOrdered(0, first);
    }
    return first - 1000;
  }

  static int forInsertAfter(List<int> orders, int index) {
    final int current = orders[index];
    if (index + 1 < orders.length) {
      return betweenOrdered(current, orders[index + 1]);
    }
    return afterLast(current);
  }
}
