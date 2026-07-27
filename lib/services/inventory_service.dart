import '../models/inventory.dart';
import '../models/paginated.dart';
import 'api_client.dart';

class InventoryService {
  final ApiClient api;
  InventoryService(this.api);

  Future<Paginated<Inventory>> list({int page = 1}) async {
    final res = await api.dio.get('/inventories', queryParameters: {'page': page});
    return Paginated.fromJson(Map<String, dynamic>.from(res.data), Inventory.fromJson);
  }

  Future<Inventory> get(int id) async {
    final res = await api.dio.get('/inventories/$id');
    return Inventory.fromJson(Map<String, dynamic>.from(res.data['data']));
  }

  Future<Inventory> create({
    required int locationId,
    required String type, // 'partial' | 'full'
    List<int> productIds = const [],
  }) async {
    final res = await api.dio.post('/inventories', data: {
      'location_id': locationId,
      'type': type,
      if (type == 'partial') 'product_ids': productIds,
    });
    return Inventory.fromJson(Map<String, dynamic>.from(res.data['data']));
  }

  /// Enregistre le comptage physique.
  /// items = [{inventory_item_id, counted_quantity, reason?}]
  Future<Inventory> count(int id, List<Map<String, dynamic>> items) async {
    final res = await api.dio.post('/inventories/$id/count', data: {'items': items});
    return Inventory.fromJson(Map<String, dynamic>.from(res.data['data']));
  }

  /// Clôture → applique les ajustements de stock pour chaque écart.
  Future<Inventory> close(int id) async {
    final res = await api.dio.post('/inventories/$id/close', data: {});
    return Inventory.fromJson(Map<String, dynamic>.from(res.data['data']));
  }
}
