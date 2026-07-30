/// Produit — miroir de ProductResource.
import '../utils/validation.dart';

class Product {
  final int id;
  final String code;
  final String? reference;
  final String name;
  final int? categoryId;
  final String? categoryName;
  final int? supplierId;
  final String? brand;
  final int purchasePrice;
  final int salePrice;
  final int minStock;
  final String unit;
  final bool isActive;
  final int? totalQuantity; // présent dans la liste (somme des stocks)

  Product({
    required this.id,
    required this.code,
    this.reference,
    required this.name,
    this.categoryId,
    this.categoryName,
    this.supplierId,
    this.brand,
    required this.purchasePrice,
    required this.salePrice,
    required this.minStock,
    required this.unit,
    required this.isActive,
    this.totalQuantity,
  });

  factory Product.fromJson(Map<String, dynamic> json) => Product(
        id: json['id'] as int,
        code: json['code'] as String,
        reference: json['reference'] as String?,
        name: json['name'] as String,
        categoryId: json['category_id'] as int?,
        // 'category' peut être un objet imbriqué (ou absent) → on en extrait le nom.
        categoryName: json['category'] is Map ? json['category']['name'] as String? : null,
        supplierId: json['supplier_id'] as int?,
        brand: json['brand'] as String?,
        purchasePrice: (json['purchase_price'] ?? 0) as int,
        salePrice: (json['sale_price'] ?? 0) as int,
        minStock: (json['min_stock'] ?? 0) as int,
        unit: (json['unit'] ?? 'unité') as String,
        isActive: parseBool(json['is_active'] ?? true),
        totalQuantity: json['total_quantity'] as int?,
      );

  /// Le stock total est-il au niveau ou sous le seuil minimum ?
  bool get isLowStock => totalQuantity != null && totalQuantity! <= minStock;
}
