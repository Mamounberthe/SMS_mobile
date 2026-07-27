import '../models/paginated.dart';
import '../models/transfer.dart';
import 'api_client.dart';

class TransferService {
  final ApiClient api;
  TransferService(this.api);

  Future<Paginated<Transfer>> list({int page = 1}) async {
    final res = await api.dio.get('/transfers', queryParameters: {'page': page});
    return Paginated.fromJson(Map<String, dynamic>.from(res.data), Transfer.fromJson);
  }

  Future<Transfer> get(int id) async {
    final res = await api.dio.get('/transfers/$id');
    return Transfer.fromJson(Map<String, dynamic>.from(res.data['data']));
  }

  Future<Transfer> create({
    required int fromLocationId,
    required int toLocationId,
    required List<Map<String, dynamic>> items,
    bool isReturn = false,
  }) async {
    final res = await api.dio.post('/transfers', data: {
      'from_location_id': fromLocationId,
      'to_location_id': toLocationId,
      'is_return': isReturn,
      'items': items,
    });
    return Transfer.fromJson(Map<String, dynamic>.from(res.data['data']));
  }

  /// dispatch / receive / cancel
  Future<Transfer> action(int id, String action) async {
    final res = await api.dio.post('/transfers/$id/$action', data: {});
    return Transfer.fromJson(Map<String, dynamic>.from(res.data['data']));
  }
}
