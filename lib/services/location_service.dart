import '../models/location.dart';
import '../utils/validation.dart';
import 'api_client.dart';

/// CRUD des lieux (dépôt & boutiques) — réservé admin.
class LocationService {
  final ApiClient api;
  LocationService(this.api);

  Future<List<Location>> list() async {
    final res = await api.dio.get('/locations');
    final data = safeCastMapList(res.data['data']);
    return data.map(Location.fromJson).toList();
  }

  Future<Location> create(Map<String, dynamic> data) async {
    final res = await api.dio.post('/locations', data: data);
    return Location.fromJson(Map<String, dynamic>.from(res.data['data']));
  }

  Future<Location> update(int id, Map<String, dynamic> data) async {
    final res = await api.dio.put('/locations/$id', data: data);
    return Location.fromJson(Map<String, dynamic>.from(res.data['data']));
  }

  Future<void> delete(int id) async {
    await api.dio.delete('/locations/$id');
  }
}
