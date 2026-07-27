import '../models/paginated.dart';
import '../models/user.dart';
import 'api_client.dart';

/// CRUD des utilisateurs & rôles (réservé admin).
class UserService {
  final ApiClient api;
  UserService(this.api);

  Future<Paginated<User>> list({int page = 1}) async {
    final res = await api.dio.get('/users', queryParameters: {'page': page});
    return Paginated.fromJson(Map<String, dynamic>.from(res.data), User.fromJson);
  }

  Future<User> create(Map<String, dynamic> data) async {
    final res = await api.dio.post('/users', data: data);
    return User.fromJson(Map<String, dynamic>.from(res.data['data']));
  }

  Future<User> update(int id, Map<String, dynamic> data) async {
    final res = await api.dio.put('/users/$id', data: data);
    return User.fromJson(Map<String, dynamic>.from(res.data['data']));
  }

  Future<void> delete(int id) async {
    await api.dio.delete('/users/$id');
  }
}
