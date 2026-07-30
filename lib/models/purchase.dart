import '../utils/validation.dart';

class PurchaseItem {
  final int id;
  final int productId;
  final String? productName;
  final int quantity;
  final int receivedQuantity;
  final int unitPrice;
  final String? lotNumber;
  final String? expiryDate;

  PurchaseItem({
    required this.id,
    required this.productId,
    this.productName,
    required this.quantity,
    required this.receivedQuantity,
    required this.unitPrice,
    this.lotNumber,
    this.expiryDate,
  });

  factory PurchaseItem.fromJson(Map<String, dynamic> json) => PurchaseItem(
        id: json['id'] as int,
        productId: json['product_id'] as int,
        productName: json['product'] is Map ? json['product']['name'] as String? : null,
        quantity: (json['quantity'] ?? 0) as int,
        receivedQuantity: (json['received_quantity'] ?? 0) as int,
        unitPrice: (json['unit_price'] ?? 0) as int,
        lotNumber: json['lot_number'] as String?,
        expiryDate: json['expiry_date'] as String?,
      );
}

/// Achat fournisseur — miroir de PurchaseResource.
class Purchase {
  final int id;
  final String reference;
  final int supplierId;
  final String? supplierName;
  final String status;
  final int totalAmount;
  final List<PurchaseItem> items;

  Purchase({
    required this.id,
    required this.reference,
    required this.supplierId,
    this.supplierName,
    required this.status,
    required this.totalAmount,
    this.items = const [],
  });

  factory Purchase.fromJson(Map<String, dynamic> json) => Purchase(
        id: json['id'] as int,
        reference: json['reference'] as String,
        supplierId: json['supplier_id'] as int,
        supplierName: json['supplier'] is Map ? json['supplier']['name'] as String? : null,
        status: json['status'] as String,
        totalAmount: (json['total_amount'] ?? 0) as int,
        items: safeCastMapList(json['items']).map(PurchaseItem.fromJson).toList(),
      );
}
