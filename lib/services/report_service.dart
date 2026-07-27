import '../models/movement.dart';
import '../models/paginated.dart';
import '../models/stock.dart';
import 'api_client.dart';

/// Rapports + vues stock/mouvements.
class ReportService {
  final ApiClient api;
  ReportService(this.api);

  /// GET /reports/stock-value → { data:[{location,total_quantity,total_value}], grand_total }
  Future<({List<Map<String, dynamic>> rows, int grandTotal})> stockValue() async {
    final res = await api.dio.get('/reports/stock-value');
    final rows = (res.data['data'] as List).cast<Map<String, dynamic>>();
    return (rows: rows, grandTotal: (res.data['grand_total'] ?? 0) as int);
  }

  /// GET /reports/low-stock → { data:[{product,location,quantity,min_stock,status}] }
  Future<List<Map<String, dynamic>>> lowStock() async {
    final res = await api.dio.get('/reports/low-stock');
    return (res.data['data'] as List).cast<Map<String, dynamic>>();
  }

  /// GET /reports/expiring → { data:[{product,location,lot_number,expiry_date,quantity,is_expired}] }
  Future<List<Map<String, dynamic>>> expiring({int days = 30}) async {
    final res = await api.dio.get('/reports/expiring', queryParameters: {'days': days});
    return (res.data['data'] as List).cast<Map<String, dynamic>>();
  }

  /// GET /reports/movements → { data:[{type,count,net_delta}] }
  Future<List<Map<String, dynamic>>> movementsSummary() async {
    final res = await api.dio.get('/reports/movements');
    return (res.data['data'] as List).cast<Map<String, dynamic>>();
  }

  /// GET /stocks — soldes par lieu (paginé).
  Future<Paginated<Stock>> stocks({int page = 1, int? locationId, int? productId}) async {
    final res = await api.dio.get('/stocks', queryParameters: {
      'page': page,
      'per_page': 50,
      if (locationId != null) 'location_id': locationId,
      if (productId != null) 'product_id': productId,
    });
    return Paginated.fromJson(Map<String, dynamic>.from(res.data), Stock.fromJson);
  }

  /// GET /movements — historique (paginé).
  Future<Paginated<StockMovement>> movements({int page = 1, int? locationId, int? productId, String? type}) async {
    final res = await api.dio.get('/movements', queryParameters: {
      'page': page,
      'per_page': 50,
      if (locationId != null) 'location_id': locationId,
      if (productId != null) 'product_id': productId,
      if (type != null) 'type': type,
    });
    return Paginated.fromJson(Map<String, dynamic>.from(res.data), StockMovement.fromJson);
  }
}
