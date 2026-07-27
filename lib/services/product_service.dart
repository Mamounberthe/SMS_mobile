import '../models/paginated.dart';
import '../models/product.dart';
import '../models/stock.dart';
import 'api_client.dart';

/// Appels liés aux produits et à leur stock.
class ProductService {
  final ApiClient api;
  ProductService(this.api);

  /// GET /products — liste paginée, avec recherche et filtres.
  Future<Paginated<Product>> list({
    String? search,
    int page = 1,
    bool lowStockOnly = false,
    String? category,
    String? brand,
    int perPage = 30,
  }) async {
    final res = await api.dio.get('/products', queryParameters: {
      'page': page,
      'per_page': perPage,
      if (search != null && search.isNotEmpty) 'search': search,
      if (lowStockOnly) 'low_stock': 1,
      if (category != null && category.isNotEmpty) 'category': category,
      if (brand != null && brand.isNotEmpty) 'brand': brand,
    });
    return Paginated.fromJson(
      Map<String, dynamic>.from(res.data),
      (j) => Product.fromJson(j),
    );
  }

  /// GET /products/{id}/stock — stock du produit par lieu.
  Future<List<Stock>> stockByLocation(int productId) async {
    final res = await api.dio.get('/products/$productId/stock');
    final data = (res.data['data'] as List).cast<Map<String, dynamic>>();
    return data.map((j) => Stock.fromJson(j)).toList();
  }

  Future<Product> create(Map<String, dynamic> data) async {
    final res = await api.dio.post('/products', data: data);
    return Product.fromJson(Map<String, dynamic>.from(res.data['data']));
  }

  Future<Product> update(int id, Map<String, dynamic> data) async {
    final res = await api.dio.put('/products/$id', data: data);
    return Product.fromJson(Map<String, dynamic>.from(res.data['data']));
  }

  Future<void> delete(int id) async {
    await api.dio.delete('/products/$id');
  }
}
