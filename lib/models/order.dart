/// Ligne de commande — miroir d'un item de OrderResource.
class OrderItem {
  final int id;
  final int productId;
  final String? productName;
  final int quantityRequested;
  final int? quantityValidated;
  final int? quantityShipped;
  final int? quantityReceived;

  OrderItem({
    required this.id,
    required this.productId,
    this.productName,
    required this.quantityRequested,
    this.quantityValidated,
    this.quantityShipped,
    this.quantityReceived,
  });

  factory OrderItem.fromJson(Map<String, dynamic> json) => OrderItem(
        id: json['id'] as int,
        productId: json['product_id'] as int,
        productName: json['product'] is Map ? json['product']['name'] as String? : null,
        quantityRequested: (json['quantity_requested'] ?? 0) as int,
        quantityValidated: json['quantity_validated'] as int?,
        quantityShipped: json['quantity_shipped'] as int?,
        quantityReceived: json['quantity_received'] as int?,
      );
}

/// Commande boutique → dépôt — miroir de OrderResource.
class Order {
  final int id;
  final String reference;
  final int storeId;
  final String? storeName;
  final String status;
  final String? requesterName;
  final List<OrderItem> items;

  Order({
    required this.id,
    required this.reference,
    required this.storeId,
    this.storeName,
    required this.status,
    this.requesterName,
    this.items = const [],
  });

  /// Montant total de la commande (calculé)
  double get totalAmount {
    // Pour l'instant, retourne 0 car nous n'avons pas les prix dans OrderItem
    // À ajuster selon vos besoins
    return 0;
  }

  factory Order.fromJson(Map<String, dynamic> json) => Order(
        id: json['id'] as int,
        reference: json['reference'] as String,
        storeId: json['store_id'] as int,
        storeName: json['store'] is Map ? json['store']['name'] as String? : null,
        status: json['status'] as String,
        requesterName: json['requester'] is Map ? json['requester']['name'] as String? : null,
        items: json['items'] is List
            ? (json['items'] as List)
                .cast<Map<String, dynamic>>()
                .map(OrderItem.fromJson)
                .toList()
            : const [],
      );
}
