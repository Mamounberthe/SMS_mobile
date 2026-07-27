import '../models/paginated.dart';
import '../models/purchase.dart';
import 'api_client.dart';

class PurchaseService {
  final ApiClient api;
  PurchaseService(this.api);

  Future<Paginated<Purchase>> list({int page = 1}) async {
    final res = await api.dio.get('/purchases', queryParameters: {'page': page});
    return Paginated.fromJson(Map<String, dynamic>.from(res.data), Purchase.fromJson);
  }

  Future<Purchase> get(int id) async {
    final res = await api.dio.get('/purchases/$id');
    return Purchase.fromJson(Map<String, dynamic>.from(res.data['data']));
  }

  Future<Purchase> create({
    required int supplierId,
    required int locationId,
    required List<Map<String, dynamic>> items,
  }) async {
    final res = await api.dio.post('/purchases', data: {
      'supplier_id': supplierId,
      'location_id': locationId,
      'items': items, // [{product_id, quantity, unit_price?, lot_number?, expiry_date?}]
    });
    return Purchase.fromJson(Map<String, dynamic>.from(res.data['data']));
  }

  Future<Purchase> markOrdered(int id) async {
    final res = await api.dio.post('/purchases/$id/order', data: {});
    return Purchase.fromJson(Map<String, dynamic>.from(res.data['data']));
  }

  /// Réception totale (les lots/péremptions saisis à la création sont utilisés).
  Future<Purchase> receive(int id) async {
    final res = await api.dio.post('/purchases/$id/receive', data: {});
    return Purchase.fromJson(Map<String, dynamic>.from(res.data['data']));
  }
}
