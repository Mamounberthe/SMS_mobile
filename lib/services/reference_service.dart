import '../models/category.dart';
import '../models/location.dart';
import '../models/supplier.dart';
import 'api_client.dart';
import 'offline_service.dart';

/// Données de référence utilisées par les listes déroulantes (lieux, fournisseurs,
/// catégories).
///
/// **Offline-first** : chaque appel tente d'abord l'API, met à jour le cache
/// SQLite en cas de succès, et retombe sur le cache si l'API est injoignable.
/// Ainsi, la création d'achat / transfert / inventaire reste possible sans
/// réseau (les listes déroulantes se remplissent depuis le cache).
class ReferenceService {
  final ApiClient api;
  final OfflineService offline;
  ReferenceService(this.api, this.offline);

  Future<List<Location>> locations({String? type}) async {
    try {
      final res = await api.dio.get('/locations', queryParameters: {
        'type': type,
        'active_only': true,
      });
      final data = (res.data['data'] as List).cast<Map<String, dynamic>>();
      final list = data.map(Location.fromJson).toList();
      // Mettre à jour le cache (liste complète, sans filtre type).
      if (type == null) await offline.cacheLocations(list);
      return list;
    } catch (_) {
      // Hors-ligne : retomber sur le cache (filtrage local par type).
      final cached = await offline.getCachedLocations();
      if (type == null) return cached;
      return cached.where((l) => l.type == type).toList();
    }
  }

  Future<Location?> warehouse() async {
    final list = await locations(type: 'warehouse');
    return list.isEmpty ? null : list.first;
  }

  Future<List<Supplier>> suppliers() async {
    try {
      final res = await api.dio.get('/suppliers');
      final data = (res.data['data'] as List).cast<Map<String, dynamic>>();
      final list = data.map(Supplier.fromJson).toList();
      await offline.cacheSuppliers(list);
      return list;
    } catch (_) {
      return offline.getCachedSuppliers();
    }
  }

  Future<List<Category>> categories() async {
    try {
      final res = await api.dio.get('/categories');
      final data = (res.data['data'] as List).cast<Map<String, dynamic>>();
      final list = data.map(Category.fromJson).toList();
      await offline.cacheCategories(list);
      return list;
    } catch (_) {
      return offline.getCachedCategories();
    }
  }
}
