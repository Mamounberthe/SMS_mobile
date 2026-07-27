import '../models/location.dart';
import '../models/order.dart';
import '../models/paginated.dart';
import 'api_client.dart';

/// Appels liés aux commandes (boutique → dépôt) et à leur cycle d'états.
class OrderService {
  final ApiClient api;
  OrderService(this.api);

  Future<Paginated<Order>> list({int page = 1, String? status}) async {
    final res = await api.dio.get('/orders', queryParameters: {
      'page': page,
      if (status != null && status.isNotEmpty) 'status': status,
    });
    return Paginated.fromJson(Map<String, dynamic>.from(res.data), Order.fromJson);
  }

  Future<Order> get(int id) async {
    final res = await api.dio.get('/orders/$id');
    return Order.fromJson(Map<String, dynamic>.from(res.data['data']));
  }

  /// POST /orders — crée une commande (statut brouillon).
  Future<Order> create({required int storeId, required List<Map<String, dynamic>> items, String? notes}) async {
    final res = await api.dio.post('/orders', data: {
      'store_id': storeId,
      if (notes != null && notes.isNotEmpty) 'notes': notes,
      'items': items, // [{product_id, quantity}, ...]
    });
    return Order.fromJson(Map<String, dynamic>.from(res.data['data']));
  }

  /// Transitions simples du cycle d'états (ex. cancel).
  Future<Order> action(int id, String action) async {
    final res = await api.dio.post('/orders/$id/$action', data: {});
    return Order.fromJson(Map<String, dynamic>.from(res.data['data']));
  }

  /// Livraison/réception : déplace le stock dépôt → boutique et passe la
  /// commande à « Reçue ».
  ///
  /// [received] (optionnel) = quantités réellement reçues, indexées par
  /// order_item_id. Si omis, chaque ligne reçoit la quantité demandée.
  Future<Order> fulfill(int id, {Map<int, int>? received}) async {
    final data = <String, dynamic>{};
    if (received != null && received.isNotEmpty) {
      data['items'] = received.entries
          .map((e) => {'order_item_id': e.key, 'quantity_received': e.value})
          .toList();
    }
    final res = await api.dio.post('/orders/$id/fulfill', data: data);
    return Order.fromJson(Map<String, dynamic>.from(res.data['data']));
  }

  /// Boutiques disponibles (pour choisir la destination d'une commande).
  Future<List<Location>> stores() async {
    final res = await api.dio.get('/locations', queryParameters: {'type': 'store', 'active_only': true});
    final data = (res.data['data'] as List).cast<Map<String, dynamic>>();
    return data.map(Location.fromJson).toList();
  }
}
