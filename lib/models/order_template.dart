/// Template de commande (panier fréquent)
class OrderTemplate {
  final int id;
  final String name;
  final List<TemplateItem> items;
  final DateTime createdAt;

  OrderTemplate({
    required this.id,
    required this.name,
    required this.items,
    required this.createdAt,
  });

  factory OrderTemplate.fromJson(Map<String, dynamic> json) => OrderTemplate(
        id: json['id'] as int,
        name: json['name'] as String,
        items: (json['items'] as List)
            .map((i) => TemplateItem.fromJson(i as Map<String, dynamic>))
            .toList(),
        createdAt: DateTime.parse(json['created_at'] as String),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'items': items.map((i) => i.toJson()).toList(),
        'created_at': createdAt.toIso8601String(),
      };
}

class TemplateItem {
  final int productId;
  final String productName;
  final int quantity;

  TemplateItem({
    required this.productId,
    required this.productName,
    required this.quantity,
  });

  factory TemplateItem.fromJson(Map<String, dynamic> json) => TemplateItem(
        productId: json['product_id'] as int,
        productName: json['product_name'] as String,
        quantity: json['quantity'] as int,
      );

  Map<String, dynamic> toJson() => {
        'product_id': productId,
        'product_name': productName,
        'quantity': quantity,
      };
}
