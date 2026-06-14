import 'package:murmur/core/utils/list_sort_order.dart';

class TodoGroup {
  TodoGroup({
    required this.id,
    required this.name,
    required this.createdAt,
    int? sortOrder,
  }) : sortOrder = sortOrder ?? ListSortOrder.defaultFromCreatedAt(createdAt);

  final String id;
  final String name;
  final DateTime createdAt;
  final int sortOrder;

  TodoGroup copyWith({
    String? id,
    String? name,
    DateTime? createdAt,
    int? sortOrder,
  }) {
    return TodoGroup(
      id: id ?? this.id,
      name: name ?? this.name,
      createdAt: createdAt ?? this.createdAt,
      sortOrder: sortOrder ?? this.sortOrder,
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'id': id,
      'name': name,
      'createdAt': createdAt.toIso8601String(),
      'sortOrder': sortOrder,
    };
  }

  factory TodoGroup.fromMap(Map<dynamic, dynamic> map) {
    final DateTime createdAt = DateTime.parse(map['createdAt'] as String);
    return TodoGroup(
      id: map['id'] as String,
      name: map['name'] as String,
      createdAt: createdAt,
      sortOrder: map['sortOrder'] as int? ??
          ListSortOrder.defaultFromCreatedAt(createdAt),
    );
  }
}
