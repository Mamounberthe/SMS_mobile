import '../models/order_template.dart';
import 'api_client.dart';

/// Service pour gérer les templates de commandes (paniers fréquents)
class TemplateService {
  final ApiClient api;
  TemplateService(this.api);

  /// Récupérer tous les templates
  Future<List<OrderTemplate>> list() async {
    final res = await api.dio.get('/order-templates');
    final data = (res.data['data'] as List).cast<Map<String, dynamic>>();
    return data.map(OrderTemplate.fromJson).toList();
  }

  /// Créer un nouveau template
  Future<OrderTemplate> create({
    required String name,
    required List<Map<String, dynamic>> items,
  }) async {
    final res = await api.dio.post('/order-templates', data: {
      'name': name,
      'items': items,
    });
    return OrderTemplate.fromJson(Map<String, dynamic>.from(res.data['data']));
  }

  /// Mettre à jour un template
  Future<OrderTemplate> update(int id, {
    String? name,
    List<Map<String, dynamic>>? items,
  }) async {
    final res = await api.dio.put('/order-templates/$id', data: {
      if (name != null) 'name': name,
      if (items != null) 'items': items,
    });
    return OrderTemplate.fromJson(Map<String, dynamic>.from(res.data['data']));
  }

  /// Supprimer un template
  Future<void> delete(int id) async {
    await api.dio.delete('/order-templates/$id');
  }
}
