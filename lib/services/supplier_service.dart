import '../models/paginated.dart';
import '../models/purchase.dart';
import '../models/supplier.dart';
import '../utils/validation.dart';
import 'api_client.dart';

/// CRUD des fournisseurs + historique des achats.
class SupplierService {
  final ApiClient api;
  SupplierService(this.api);

  Future<List<Supplier>> list() async {
    final res = await api.dio.get('/suppliers');
    final data = safeCastMapList(res.data['data']);
    return data.map(Supplier.fromJson).toList();
  }

  Future<Supplier> create(Map<String, dynamic> data) async {
    final res = await api.dio.post('/suppliers', data: data);
    return Supplier.fromJson(Map<String, dynamic>.from(res.data['data']));
  }

  Future<Supplier> update(int id, Map<String, dynamic> data) async {
    final res = await api.dio.put('/suppliers/$id', data: data);
    return Supplier.fromJson(Map<String, dynamic>.from(res.data['data']));
  }

  Future<void> delete(int id) async {
    await api.dio.delete('/suppliers/$id');
  }

  Future<Paginated<Purchase>> purchases(int id) async {
    final res = await api.dio.get('/suppliers/$id/purchases');
    return Paginated.fromJson(Map<String, dynamic>.from(res.data), Purchase.fromJson);
  }
}
