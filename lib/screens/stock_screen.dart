import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/stock.dart';
import '../services/api_client.dart';
import '../services/report_service.dart';
import '../services/export_service.dart';
import '../services/offline_service.dart';
import '../theme.dart';
import '../widgets/app_card.dart';
import '../widgets/empty_state.dart';
import '../widgets/skeleton.dart';

/// Vue globale du stock (soldes par lieu).
class StockScreen extends StatefulWidget {
  const StockScreen({super.key});

  @override
  State<StockScreen> createState() => _StockScreenState();
}

class _StockScreenState extends State<StockScreen> {
  late final ReportService _service;
  final List<Stock> _items = [];
  bool _loading = false;
  String? _error;
  int _page = 1;
  int _lastPage = 1;

  @override
  void initState() {
    super.initState();
    _service = ReportService(context.read<ApiClient>());
    _load(reset: true);
  }

  Future<void> _load({bool reset = false}) async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _error = null;
      if (reset) {
        _page = 1;
        _items.clear();
      }
    });
    try {
      final res = await _service.stocks(page: _page);
      setState(() {
        _items.addAll(res.items);
        _lastPage = res.lastPage;
      });
      // Mettre à jour le cache pour usage hors-ligne (page 1 seulement)
      if (_page == 1) {
        final offline = context.read<OfflineService>();
        await offline.cacheStocks(res.items);
      }
    } catch (e) {
      // En cas d'erreur, essayer de charger depuis le cache
      if (_page == 1 && _items.isEmpty) {
        try {
          final offline = context.read<OfflineService>();
          final cached = await offline.getCachedStocks();
          if (cached.isNotEmpty) {
            setState(() {
              _items.addAll(cached);
              _lastPage = 1;
              _error = null;
            });
            return;
          }
        } catch (_) {
          // Ignorer les erreurs de cache
        }
      }
      setState(() => _error = ApiClient.errorMessage(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _exportStock() async {
    if (_items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Aucune donnée de stock à exporter')),
      );
      return;
    }
    try {
      final exportService = ExportService();
      final stockData = _items.map((st) => {
        'product_name': st.productName,
        'location_name': st.location?.name,
        'total_quantity': st.quantity,
        'available_quantity': st.available,
      }).toList();
      await exportService.exportStock(stockData);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur lors de l\'export: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = AppSurface.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Stock global'),
        actions: [
          IconButton(
            tooltip: 'Exporter en CSV',
            icon: const Icon(Icons.download),
            onPressed: _exportStock,
          ),
        ],
      ),
      body: _loading && _items.isEmpty
          ? const SkeletonList()
          : _error != null && _items.isEmpty
              ? EmptyState(icon: Icons.cloud_off, message: _error!, actionLabel: 'Réessayer', onAction: () => _load(reset: true))
              : _items.isEmpty
                  ? const EmptyState(icon: Icons.inventory_2_outlined, message: 'Aucun stock.')
                  : RefreshIndicator(
                      onRefresh: () => _load(reset: true),
                      child: ListView.separated(
                        padding: const EdgeInsets.all(Insets.lg),
                        itemCount: _items.length + 1,
                        separatorBuilder: (_, _) => const SizedBox(height: Insets.sm),
                        itemBuilder: (context, i) {
                          if (i == _items.length) {
                            if (_page < _lastPage) {
                              return Padding(
                                padding: const EdgeInsets.all(Insets.md),
                                child: Center(
                                  child: _loading
                                      ? const CircularProgressIndicator()
                                      : OutlinedButton(
                                          onPressed: () {
                                            _page++;
                                            _load();
                                          },
                                          child: const Text('Charger plus'),
                                        ),
                                ),
                              );
                            }
                            return const SizedBox.shrink();
                          }
                          final st = _items[i];
                          return AppCard(
                            padding: const EdgeInsets.symmetric(horizontal: Insets.md, vertical: Insets.sm),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(st.productName ?? 'Produit #${st.productId}',
                                          style: const TextStyle(fontWeight: FontWeight.w600)),
                                      const SizedBox(height: 2),
                                      Text(st.location?.name ?? 'Lieu #${st.locationId}',
                                          style: TextStyle(color: s.muted, fontSize: 13)),
                                    ],
                                  ),
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text('${st.quantity}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                    if (st.reservedQuantity > 0)
                                      Text('dispo ${st.available}', style: TextStyle(color: s.muted, fontSize: 11)),
                                  ],
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
    );
  }
}
