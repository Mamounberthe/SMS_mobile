/// Mouvement de stock — miroir de StockMovementResource (traçabilité).
class StockMovement {
  final int id;
  final String? productName;
  final String? locationName;
  final String type;
  final int quantityDelta;
  final int quantityAfter;
  final String? userName;
  final String? note;
  final DateTime? createdAt;

  StockMovement({
    required this.id,
    this.productName,
    this.locationName,
    required this.type,
    required this.quantityDelta,
    required this.quantityAfter,
    this.userName,
    this.note,
    this.createdAt,
  });

  factory StockMovement.fromJson(Map<String, dynamic> json) => StockMovement(
        id: json['id'] as int,
        productName: json['product'] is Map ? json['product']['name'] as String? : null,
        locationName: json['location'] is Map ? json['location']['name'] as String? : null,
        type: json['type'] as String,
        quantityDelta: (json['quantity_delta'] ?? 0) as int,
        quantityAfter: (json['quantity_after'] ?? 0) as int,
        userName: json['user'] is Map ? json['user']['name'] as String? : null,
        note: json['note'] as String?,
        createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at'].toString()) : null,
      );

  /// Libellé lisible du type de mouvement.
  String get typeLabel => switch (type) {
        'purchase_in' => 'Réception achat',
        'order_out' => 'Sortie commande',
        'order_in' => 'Entrée commande',
        'transfer_out' => 'Sortie transfert',
        'transfer_in' => 'Entrée transfert',
        'adjustment' => 'Ajustement',
        'return_in' => 'Retour',
        _ => type,
      };
}
