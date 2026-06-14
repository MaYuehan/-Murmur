import 'package:murmur/core/utils/list_sort_order.dart';

class TodoSubItem {
  TodoSubItem({
    required this.id,
    required this.title,
    this.isCompleted = false,
    int? sortOrder,
  }) : _sortOrder = sortOrder;

  final String id;
  final String title;
  final bool isCompleted;
  final int? _sortOrder;

  int get sortOrder {
    final int? stored = _sortOrder;
    if (stored != null) {
      return stored;
    }
    final int? idMicros = int.tryParse(id);
    if (idMicros != null) {
      return ListSortOrder.defaultFromCreatedAt(
        DateTime.fromMicrosecondsSinceEpoch(idMicros),
      );
    }
    return ListSortOrder.defaultNow();
  }

  TodoSubItem copyWith({
    String? id,
    String? title,
    bool? isCompleted,
    int? sortOrder,
  }) {
    return TodoSubItem(
      id: id ?? this.id,
      title: title ?? this.title,
      isCompleted: isCompleted ?? this.isCompleted,
      sortOrder: sortOrder ?? _sortOrder,
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'id': id,
      'title': title,
      'isCompleted': isCompleted,
      'sortOrder': sortOrder,
    };
  }

  factory TodoSubItem.fromMap(Map<dynamic, dynamic> map) {
    final String id = map['id'] as String;
    return TodoSubItem(
      id: id,
      title: map['title'] as String,
      isCompleted: map['isCompleted'] as bool? ?? false,
      sortOrder: map['sortOrder'] as int?,
    );
  }
}
