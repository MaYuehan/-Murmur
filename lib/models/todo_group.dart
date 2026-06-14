class TodoGroup {
  const TodoGroup({
    required this.id,
    required this.name,
    required this.createdAt,
  });

  final String id;
  final String name;
  final DateTime createdAt;

  TodoGroup copyWith({
    String? id,
    String? name,
    DateTime? createdAt,
  }) {
    return TodoGroup(
      id: id ?? this.id,
      name: name ?? this.name,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'id': id,
      'name': name,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory TodoGroup.fromMap(Map<dynamic, dynamic> map) {
    return TodoGroup(
      id: map['id'] as String,
      name: map['name'] as String,
      createdAt: DateTime.parse(map['createdAt'] as String),
    );
  }
}
