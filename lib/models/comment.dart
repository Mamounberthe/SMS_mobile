/// Modèle de commentaire sur une commande
class Comment {
  final int id;
  final int orderId;
  final String content;
  final String authorName;
  final DateTime createdAt;
  final DateTime? updatedAt;

  Comment({
    required this.id,
    required this.orderId,
    required this.content,
    required this.authorName,
    required this.createdAt,
    this.updatedAt,
  });

  factory Comment.fromJson(Map<String, dynamic> json) => Comment(
        id: json['id'] as int,
        orderId: json['order_id'] as int,
        content: json['content'] as String,
        authorName: json['author_name'] as String,
        createdAt: DateTime.parse(json['created_at'] as String),
        updatedAt: json['updated_at'] != null 
            ? DateTime.parse(json['updated_at'] as String) 
            : null,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'order_id': orderId,
        'content': content,
        'author_name': authorName,
        'created_at': createdAt.toIso8601String(),
        if (updatedAt != null) 'updated_at': updatedAt!.toIso8601String(),
      };
}
