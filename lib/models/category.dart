/// Catégorie de produits — miroir de CategoryResource.
class Category {
  final int id;
  final String name;
  final String? description;
  final int? parentId;

  Category({required this.id, required this.name, this.description, this.parentId});

  factory Category.fromJson(Map<String, dynamic> json) => Category(
        id: json['id'] as int,
        name: json['name'] as String,
        description: json['description'] as String?,
        parentId: json['parent_id'] as int?,
      );
}
