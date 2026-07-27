class InventoryItem {
  final int id;
  final int productId;
  final String? productName;
  final int systemQuantity;
  final int? countedQuantity;
  final int? difference;
  final String? reason;

  InventoryItem({
    required this.id,
    required this.productId,
    this.productName,
    required this.systemQuantity,
    this.countedQuantity,
    this.difference,
    this.reason,
  });

  factory InventoryItem.fromJson(Map<String, dynamic> json) => InventoryItem(
        id: json['id'] as int,
        productId: json['product_id'] as int,
        productName: json['product'] is Map ? json['product']['name'] as String? : null,
        systemQuantity: (json['system_quantity'] ?? 0) as int,
        countedQuantity: json['counted_quantity'] as int?,
        difference: json['difference'] as int?,
        reason: json['reason'] as String?,
      );
}

/// Inventaire — miroir de InventoryResource.
class Inventory {
  final int id;
  final String reference;
  final int locationId;
  final String? locationName;
  final String type; // partial | full
  final String status; // open | counting | closed
  final List<InventoryItem> items;

  Inventory({
    required this.id,
    required this.reference,
    required this.locationId,
    this.locationName,
    required this.type,
    required this.status,
    this.items = const [],
  });

  factory Inventory.fromJson(Map<String, dynamic> json) => Inventory(
        id: json['id'] as int,
        reference: json['reference'] as String,
        locationId: json['location_id'] as int,
        locationName: json['location'] is Map ? json['location']['name'] as String? : null,
        type: json['type'] as String,
        status: json['status'] as String,
        items: json['items'] is List
            ? (json['items'] as List).cast<Map<String, dynamic>>().map(InventoryItem.fromJson).toList()
            : const [],
      );
}
