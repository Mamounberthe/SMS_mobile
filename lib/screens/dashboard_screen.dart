import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';

import '../providers/auth_provider.dart';
import '../services/api_client.dart';
import '../theme.dart';
import '../utils/format.dart';
import '../widgets/app_card.dart';
import '../widgets/empty_state.dart';
import '../widgets/kpi_card.dart';
import '../widgets/page_header.dart';
import '../widgets/quick_actions.dart';
import '../widgets/skeleton.dart';

/// Tableau de bord — corps hébergé dans AppShell (pas de Scaffold propre).
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  late Future<Map<String, dynamic>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<Map<String, dynamic>> _load() async {
    final api = context.read<ApiClient>();
    final res = await api.dio.get('/dashboard');
    return Map<String, dynamic>.from(res.data as Map);
  }

  void _refresh() => setState(() => _future = _load());

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    return SafeArea(
      child: RefreshIndicator(
        onRefresh: () async => _refresh(),
        child: FutureBuilder<Map<String, dynamic>>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return ListView(
                padding: const EdgeInsets.all(Insets.xl),
                children: const [
                  SkeletonBox(width: 200, height: 26),
                  SizedBox(height: Insets.xl),
                  SkeletonGrid(count: 8, columns: 4),
                ],
              );
            }
            if (snapshot.hasError) {
              return EmptyState(
                icon: Icons.cloud_off,
                message: ApiClient.errorMessage(snapshot.error!),
                actionLabel: 'Réessayer',
                onAction: _refresh,
              );
            }
            final d = snapshot.data!;
            return ListView(
              padding: const EdgeInsets.all(Insets.xl),
              children: [
                PageHeader(
                  title: 'Tableau de bord',
                  subtitle: 'Bonjour ${auth.user?.name ?? ''}',
                  actions: [
                    IconButton(onPressed: _refresh, icon: const Icon(Icons.refresh), tooltip: 'Actualiser'),
                  ],
                ),
                Text('Actions rapides',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppSurface.of(context).muted)),
                const SizedBox(height: Insets.md),
                QuickActions(onDone: _refresh),
                const SizedBox(height: Insets.xl),
                Text('Vue d\'ensemble',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppSurface.of(context).muted)),
                const SizedBox(height: Insets.md),
                LayoutBuilder(
                  builder: (context, c) {
                    final cols = c.maxWidth >= 1200 ? 4 : (c.maxWidth >= 760 ? 3 : 2);
                    return GridView.count(
                      crossAxisCount: cols,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      mainAxisSpacing: Insets.lg,
                      crossAxisSpacing: Insets.lg,
                      childAspectRatio: 1.55,
                      children: [
                        KpiCard(icon: Icons.payments_rounded, label: 'Valeur du stock', value: fcfa((d['stock_value'] ?? 0) as int), color: AppColors.brand),
                        KpiCard(icon: Icons.category_rounded, label: 'Produits', value: '${d['products_count'] ?? 0}', color: Colors.blue),
                        KpiCard(icon: Icons.trending_down_rounded, label: 'Stock faible', value: '${d['low_stock_count'] ?? 0}', color: Colors.orange),
                        KpiCard(icon: Icons.error_outline_rounded, label: 'Ruptures', value: '${d['out_of_stock_count'] ?? 0}', color: Colors.red),
                        KpiCard(icon: Icons.schedule_rounded, label: 'Bientôt périmés', value: '${d['near_expiry_count'] ?? 0}', color: Colors.amber),
                        KpiCard(icon: Icons.dangerous_rounded, label: 'Expirés', value: '${d['expired_count'] ?? 0}', color: Colors.deepOrange),
                        KpiCard(icon: Icons.receipt_long_rounded, label: 'Cmd à traiter', value: '${d['orders_to_process'] ?? 0}', color: Colors.indigo),
                        KpiCard(icon: Icons.shopping_cart_rounded, label: 'Achats en cours', value: '${d['pending_purchases'] ?? 0}', color: Colors.purple),
                        KpiCard(icon: Icons.notifications_rounded, label: 'Notifications', value: '${d['unread_notifications'] ?? 0}', color: Colors.pink),
                      ],
                    );
                  },
                ),
                const SizedBox(height: Insets.xxl),
                // Graphique d'évolution du stock
                _buildStockChart(d),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildStockChart(Map<String, dynamic> data) {
    final s = AppSurface.of(context);
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Évolution du stock', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: Insets.md),
          SizedBox(
            height: 200,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: 100,
                barTouchData: BarTouchData(enabled: false),
                titlesData: FlTitlesData(
                  show: true,
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        const labels = ['Lun', 'Mar', 'Mer', 'Jeu', 'Ven', 'Sam', 'Dim'];
                        return Text(labels[value.toInt() % 7], style: TextStyle(color: s.muted, fontSize: 11));
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  topTitles: AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                ),
                gridData: FlGridData(show: false),
                borderData: FlBorderData(show: false),
                barGroups: [
                  BarChartGroupData(
                    x: 0,
                    barRods: [
                      BarChartRodData(
                        toY: (data['stock_monday'] ?? 50) as double,
                        color: AppColors.brand,
                        width: 16,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ],
                  ),
                  BarChartGroupData(
                    x: 1,
                    barRods: [
                      BarChartRodData(
                        toY: (data['stock_tuesday'] ?? 60) as double,
                        color: AppColors.brand,
                        width: 16,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ],
                  ),
                  BarChartGroupData(
                    x: 2,
                    barRods: [
                      BarChartRodData(
                        toY: (data['stock_wednesday'] ?? 55) as double,
                        color: AppColors.brand,
                        width: 16,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ],
                  ),
                  BarChartGroupData(
                    x: 3,
                    barRods: [
                      BarChartRodData(
                        toY: (data['stock_thursday'] ?? 70) as double,
                        color: AppColors.brand,
                        width: 16,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ],
                  ),
                  BarChartGroupData(
                    x: 4,
                    barRods: [
                      BarChartRodData(
                        toY: (data['stock_friday'] ?? 65) as double,
                        color: AppColors.brand,
                        width: 16,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ],
                  ),
                  BarChartGroupData(
                    x: 5,
                    barRods: [
                      BarChartRodData(
                        toY: (data['stock_saturday'] ?? 80) as double,
                        color: AppColors.brand,
                        width: 16,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ],
                  ),
                  BarChartGroupData(
                    x: 6,
                    barRods: [
                      BarChartRodData(
                        toY: (data['stock_sunday'] ?? 75) as double,
                        color: AppColors.brand,
                        width: 16,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
