import '../models/category.dart';
import '../utils/validation.dart';
import 'api_client.dart';

/// CRUD des catégories de produits.
class CategoryService {
  final ApiClient api;
  CategoryService(this.api);

  Future<List<Category>> list() async {
    final res = await api.dio.get('/categories');
    final data = safeCastMapList(res.data['data']);
    return data.map(Category.fromJson).toList();
  }

  Future<Category> create(Map<String, dynamic> data) async {
    final res = await api.dio.post('/categories', data: data);
    return Category.fromJson(Map<String, dynamic>.from(res.data['data']));
  }

  Future<Category> update(int id, Map<String, dynamic> data) async {
    final res = await api.dio.put('/categories/$id', data: data);
    return Category.fromJson(Map<String, dynamic>.from(res.data['data']));
  }

  Future<void> delete(int id) async {
    await api.dio.delete('/categories/$id');
  }
}
