import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/api_client.dart';
import '../services/report_service.dart';
import '../theme.dart';
import '../utils/format.dart';
import '../widgets/app_card.dart';
import '../widgets/empty_state.dart';
import '../widgets/responsive.dart';
import '../widgets/skeleton.dart';
import 'movements_screen.dart';
import 'stock_screen.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  late final ReportService _service;
  bool _loading = true;
  String? _error;

  ({List<Map<String, dynamic>> rows, int grandTotal})? _stockValue;
  List<Map<String, dynamic>> _lowStock = [];
  List<Map<String, dynamic>> _expiring = [];
  List<Map<String, dynamic>> _movements = [];

  @override
  void initState() {
    super.initState();
    _service = ReportService(context.read<ApiClient>());
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        _service.stockValue(),
        _service.lowStock(),
        _service.expiring(),
        _service.movementsSummary(),
      ]);
      setState(() {
        _stockValue = results[0] as ({List<Map<String, dynamic>> rows, int grandTotal});
        _lowStock = results[1] as List<Map<String, dynamic>>;
        _expiring = results[2] as List<Map<String, dynamic>>;
        _movements = results[3] as List<Map<String, dynamic>>;
      });
    } catch (e) {
      setState(() => _error = ApiClient.errorMessage(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = AppSurface.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Rapports')),
      body: _loading
          ? const SkeletonList()
          : _error != null
              ? EmptyState(icon: Icons.cloud_off, message: _error!, actionLabel: 'Réessayer', onAction: _load)
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.all(Insets.lg),
                    children: [
                      // Liens rapides
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () => Navigator.of(context)
                                  .push(MaterialPageRoute(builder: (_) => const StockScreen())),
                              icon: const Icon(Icons.inventory),
                              label: const Text('Stock global'),
                            ),
                          ),
                          const SizedBox(width: Insets.sm),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () => Navigator.of(context)
                                  .push(MaterialPageRoute(builder: (_) => const MovementsScreen())),
                              icon: const Icon(Icons.history),
                              label: const Text('Mouvements'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: Insets.lg),

                      ResponsiveWrap(
                        minItemWidth: 440,
                        children: [
                      // Valeur du stock
                      _section(
                        'Valeur du stock',
                        Icons.payments_rounded,
                        AppColors.brand,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(fcfa(_stockValue?.grandTotal ?? 0),
                                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
                            const SizedBox(height: Insets.sm),
                            ...(_stockValue?.rows ?? []).map((r) => Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 2),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text('${r['location'] ?? 'Lieu'}', style: TextStyle(color: s.muted)),
                                      Text(fcfa((r['total_value'] ?? 0) as int),
                                          style: const TextStyle(fontWeight: FontWeight.w600)),
                                    ],
                                  ),
                                )),
                          ],
                        ),
                      ),

                      // Stock faible / ruptures
                      _section(
                        'Stock faible / ruptures (${_lowStock.length})',
                        Icons.trending_down_rounded,
                        Colors.orange,
                        child: _lowStock.isEmpty
                            ? Text('Aucun', style: TextStyle(color: s.muted))
                            : Column(
                                children: _lowStock.take(20).map((r) {
                                  final out = r['status'] == 'out_of_stock';
                                  return ListTile(
                                    dense: true,
                                    contentPadding: EdgeInsets.zero,
                                    title: Text('${r['product']}'),
                                    subtitle: Text('${r['location']}', style: TextStyle(color: s.muted)),
                                    trailing: Text('${r['quantity']}/${r['min_stock']}',
                                        style: TextStyle(
                                            color: out ? Colors.red : Colors.orange.shade800,
                                            fontWeight: FontWeight.bold)),
                                  );
                                }).toList(),
                              ),
                      ),

                      // Péremptions
                      _section(
                        'Péremptions ≤ 30 j (${_expiring.length})',
                        Icons.schedule_rounded,
                        Colors.amber,
                        child: _expiring.isEmpty
                            ? Text('Aucun', style: TextStyle(color: s.muted))
                            : Column(
                                children: _expiring.take(20).map((r) {
                                  final expired = r['is_expired'] == true;
                                  return ListTile(
                                    dense: true,
                                    contentPadding: EdgeInsets.zero,
                                    title: Text('${r['product']}'),
                                    subtitle: Text('${r['location']} · lot ${r['lot_number'] ?? 'n/a'}',
                                        style: TextStyle(color: s.muted)),
                                    trailing: Text('${r['expiry_date']}',
                                        style: TextStyle(
                                            color: expired ? Colors.red : Colors.amber.shade800,
                                            fontWeight: FontWeight.w600, fontSize: 12)),
                                  );
                                }).toList(),
                              ),
                      ),

                      // Synthèse mouvements
                      _section(
                        'Mouvements (synthèse)',
                        Icons.swap_vert_rounded,
                        Colors.indigo,
                        child: _movements.isEmpty
                            ? Text('Aucun', style: TextStyle(color: s.muted))
                            : Column(
                                children: _movements.map((r) {
                                  final net = (r['net_delta'] ?? 0) as int;
                                  return Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 2),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text('${r['type']}  (${r['count']})', style: TextStyle(color: s.muted)),
                                        Text(net >= 0 ? '+$net' : '$net',
                                            style: TextStyle(
                                                fontWeight: FontWeight.w600,
                                                color: net >= 0 ? Colors.green : Colors.red)),
                                      ],
                                    ),
                                  );
                                }).toList(),
                              ),
                      ),
                        ],
                      ),
                    ],
                  ),
                ),
    );
  }

  Widget _section(String title, IconData icon, Color color, {required Widget child}) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: Insets.sm),
              Expanded(
                child: Text(title,
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
              ),
            ],
          ),
          const SizedBox(height: Insets.md),
          child,
        ],
      ),
    );
  }
}
