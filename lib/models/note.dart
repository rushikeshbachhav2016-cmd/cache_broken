class Note {
  Note({
    required this.id,
    required this.title,
    required this.body,
    required this.createdAt,
    required this.updatedAt,
    this.tags = const [],
  });

  final int id;
  final String title;
  final String body;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<String> tags;

  Map<String, Object?> toRow() => {
        'id': id,
        'title': title,
        'body': body,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };

  static Note fromRow(Map<String, Object?> r, {List<String> tags = const []}) =>
      Note(
        id: r['id']! as int,
        title: r['title']! as String,
        body: (r['body'] as String?) ?? '',
        createdAt: DateTime.parse(r['created_at']! as String),
        updatedAt: DateTime.parse(r['updated_at']! as String),
        tags: tags,
      );
}

class Attachment {
  Attachment({required this.noteId, required this.path, required this.bytes});
  final int noteId;
  final String path;
  final int bytes;
}
