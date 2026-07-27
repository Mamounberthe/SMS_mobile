class TransferItem {
  final int id;
  final int productId;
  final String? productName;
  final int quantity;
  final int? quantityReceived;

  TransferItem({
    required this.id,
    required this.productId,
    this.productName,
    required this.quantity,
    this.quantityReceived,
  });

  factory TransferItem.fromJson(Map<String, dynamic> json) => TransferItem(
        id: json['id'] as int,
        productId: json['product_id'] as int,
        productName: json['product'] is Map ? json['product']['name'] as String? : null,
        quantity: (json['quantity'] ?? 0) as int,
        quantityReceived: json['quantity_received'] as int?,
      );
}

/// Transfert lieu → lieu (retours inclus) — miroir de TransferResource.
class Transfer {
  final int id;
  final String reference;
  final int fromLocationId;
  final String? fromName;
  final int toLocationId;
  final String? toName;
  final String status;
  final bool isReturn;
  final List<TransferItem> items;

  Transfer({
    required this.id,
    required this.reference,
    required this.fromLocationId,
    this.fromName,
    required this.toLocationId,
    this.toName,
    required this.status,
    required this.isReturn,
    this.items = const [],
  });

  factory Transfer.fromJson(Map<String, dynamic> json) => Transfer(
        id: json['id'] as int,
        reference: json['reference'] as String,
        fromLocationId: json['from_location_id'] as int,
        fromName: json['from_location'] is Map ? json['from_location']['name'] as String? : null,
        toLocationId: json['to_location_id'] as int,
        toName: json['to_location'] is Map ? json['to_location']['name'] as String? : null,
        status: json['status'] as String,
        isReturn: (json['is_return'] ?? false) as bool,
        items: json['items'] is List
            ? (json['items'] as List).cast<Map<String, dynamic>>().map(TransferItem.fromJson).toList()
            : const [],
      );
}
