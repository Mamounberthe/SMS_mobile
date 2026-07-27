import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/movement.dart';
import '../services/api_client.dart';
import '../services/report_service.dart';
import '../services/export_service.dart';
import '../theme.dart';
import '../widgets/app_card.dart';
import '../widgets/empty_state.dart';
import '../widgets/skeleton.dart';

/// Historique des mouvements de stock (traçabilité).
class MovementsScreen extends StatefulWidget {
  const MovementsScreen({super.key});

  @override
  State<MovementsScreen> createState() => _MovementsScreenState();
}

class _MovementsScreenState extends State<MovementsScreen> {
  late final ReportService _service;
  final List<StockMovement> _items = [];
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
      final res = await _service.movements(page: _page);
      setState(() {
        _items.addAll(res.items);
        _lastPage = res.lastPage;
      });
    } catch (e) {
      setState(() => _error = ApiClient.errorMessage(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _date(DateTime? d) => d == null
      ? ''
      : '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

  Future<void> _exportMovements() async {
    if (_items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Aucun mouvement à exporter')),
      );
      return;
    }
    try {
      final exportService = ExportService();
      final movementsData = _items.map((m) => {
        'product_name': m.productName,
        'type': m.typeLabel,
        'location_name': m.locationName,
        'user_name': m.userName,
        'quantity': m.quantityDelta,
        'created_at': m.createdAt?.toIso8601String(),
      }).toList();
      await exportService.exportMovements(movementsData);
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
        title: const Text('Mouvements'),
        actions: [
          IconButton(
            tooltip: 'Exporter en CSV',
            icon: const Icon(Icons.download),
            onPressed: _exportMovements,
          ),
        ],
      ),
      body: _loading && _items.isEmpty
          ? const SkeletonList()
          : _error != null && _items.isEmpty
              ? EmptyState(icon: Icons.cloud_off, message: _error!, actionLabel: 'Réessayer', onAction: () => _load(reset: true))
              : _items.isEmpty
                  ? const EmptyState(icon: Icons.history, message: 'Aucun mouvement.')
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
                          final m = _items[i];
                          final positive = m.quantityDelta >= 0;
                          return AppCard(
                            padding: const EdgeInsets.symmetric(horizontal: Insets.md, vertical: Insets.sm),
                            child: Row(
                              children: [
                                Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: (positive ? Colors.green : Colors.red).withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(Radii.sm),
                                  ),
                                  child: Icon(positive ? Icons.south_west : Icons.north_east,
                                      color: positive ? Colors.green : Colors.red, size: 18),
                                ),
                                const SizedBox(width: Insets.md),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(m.productName ?? 'Produit #${m.id}',
                                          maxLines: 1, overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(fontWeight: FontWeight.w600)),
                                      const SizedBox(height: 2),
                                      Text('${m.typeLabel} · ${m.locationName ?? ''}${m.userName != null ? ' · ${m.userName}' : ''}',
                                          maxLines: 1, overflow: TextOverflow.ellipsis,
                                          style: TextStyle(color: s.muted, fontSize: 12)),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: Insets.sm),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(positive ? '+${m.quantityDelta}' : '${m.quantityDelta}',
                                        style: TextStyle(fontWeight: FontWeight.bold, color: positive ? Colors.green : Colors.red)),
                                    Text(_date(m.createdAt), style: TextStyle(color: s.muted, fontSize: 11)),
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
