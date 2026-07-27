import 'location.dart';

/// Solde de stock d'un produit dans un lieu — miroir de StockResource.
class Stock {
  final int id;
  final int productId;
  final String? productName;
  final int locationId;
  final Location? location;
  final int quantity;
  final int reservedQuantity;
  final int available;

  Stock({
    required this.id,
    required this.productId,
    this.productName,
    required this.locationId,
    this.location,
    required this.quantity,
    required this.reservedQuantity,
    required this.available,
  });

  factory Stock.fromJson(Map<String, dynamic> json) => Stock(
        id: json['id'] as int,
        productId: json['product_id'] as int,
        productName: json['product'] is Map ? json['product']['name'] as String? : null,
        locationId: json['location_id'] as int,
        location: json['location'] is Map
            ? Location.fromJson(Map<String, dynamic>.from(json['location']))
            : null,
        quantity: (json['quantity'] ?? 0) as int,
        reservedQuantity: (json['reserved_quantity'] ?? 0) as int,
        available: (json['available'] ?? 0) as int,
      );
}
