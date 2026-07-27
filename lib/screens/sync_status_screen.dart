import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/api_client.dart';
import '../services/sync_service.dart';
import '../services/notification_service.dart';
import '../services/analytics_service.dart';
import '../theme.dart';
import '../widgets/app_card.dart';
import '../widgets/empty_state.dart';
import '../widgets/page_header.dart';
import '../widgets/skeleton.dart';

/// Écran de statut de synchronisation hors-ligne
class SyncStatusScreen extends StatefulWidget {
  const SyncStatusScreen({super.key});

  @override
  State<SyncStatusScreen> createState() => _SyncStatusScreenState();
}

class _SyncStatusScreenState extends State<SyncStatusScreen> {
  late final SyncService _syncService;
  SyncResult? _lastResult;
  bool _syncing = false;

  @override
  void initState() {
    super.initState();
    _syncService = context.read<SyncService>();
  }

  Future<void> _syncNow() async {
    setState(() => _syncing = true);
    final result = await _syncService.syncAll();
    setState(() {
      _lastResult = result;
      _syncing = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = AppSurface.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Synchronisation')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(Insets.xl, Insets.xl, Insets.xl, 0),
            child: PageHeader(
              title: 'Statut de synchronisation',
              actions: [
                if (!_syncing)
                  FilledButton.icon(
                    onPressed: _syncNow,
                    icon: const Icon(Icons.sync),
                    label: const Text('Synchroniser'),
                  )
                else
                  const Padding(
                    padding: EdgeInsets.all(8.0),
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: FutureBuilder(
              future: _syncService.getPendingItems(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const SkeletonList();
                }
                if (snapshot.hasError) {
                  return EmptyState(
                    icon: Icons.error_outline,
                    message: 'Erreur: ${snapshot.error}',
                  );
                }
                final pending = snapshot.data!;
                return ListView(
                  padding: const EdgeInsets.all(Insets.xl),
                  children: [
                    // État de connexion
                    _buildConnectionCard(s),
                    const SizedBox(height: Insets.lg),
                    
                    // Éléments en attente
                    _buildPendingSection(pending, s),
                    const SizedBox(height: Insets.lg),
                    
                    // Dernier résultat
                    if (_lastResult != null) _buildLastResultCard(_lastResult!, s),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConnectionCard(AppSurface s) {
    return AppCard(
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: (_syncService.isOnline ? Colors.green : Colors.red).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(Radii.md),
            ),
            child: Icon(
              _syncService.isOnline ? Icons.wifi : Icons.wifi_off,
              color: _syncService.isOnline ? Colors.green : Colors.red,
            ),
          ),
          const SizedBox(width: Insets.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _syncService.isOnline ? 'Connecté' : 'Hors ligne',
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                ),
                Text(
                  _syncService.isOnline ? 'Synchronisation automatique activée' : 'Mode hors-ligne',
                  style: TextStyle(color: s.muted, fontSize: 13),
                ),
              ],
            ),
          ),
          if (_syncService.lastSyncTime != null)
            Text(
              _formatDate(_syncService.lastSyncTime!),
              style: TextStyle(color: s.muted, fontSize: 12),
            ),
        ],
      ),
    );
  }

  Widget _buildPendingSection(dynamic pending, AppSurface s) {
    final total = pending.total;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Éléments en attente', style: Theme.of(context).textTheme.titleMedium),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: total > 0 ? Colors.orange.withValues(alpha: 0.15) : s.surfaceAlt,
                borderRadius: BorderRadius.circular(Radii.pill),
              ),
              child: Text(
                '$total',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: total > 0 ? Colors.orange.shade800 : s.text,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: Insets.md),
        if (total == 0)
          AppCard(
            child: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.green),
                const SizedBox(width: Insets.md),
                Expanded(
                  child: Text('Tout est synchronisé', style: TextStyle(color: s.muted)),
                ),
              ],
            ),
          )
        else ...[
          if (pending.orders.isNotEmpty) _buildPendingItem('Commandes', pending.orders.length, Icons.receipt_long, Colors.blue, s),
          if (pending.purchases.isNotEmpty) _buildPendingItem('Achats', pending.purchases.length, Icons.shopping_cart, Colors.purple, s),
          if (pending.transfers.isNotEmpty) _buildPendingItem('Transferts', pending.transfers.length, Icons.swap_horiz, Colors.indigo, s),
          if (pending.inventories.isNotEmpty) _buildPendingItem('Inventaires', pending.inventories.length, Icons.fact_check, Colors.teal, s),
        ],
      ],
    );
  }

  Widget _buildPendingItem(String label, int count, IconData icon, Color color, AppSurface s) {
    return Padding(
      padding: const EdgeInsets.only(bottom: Insets.sm),
      child: AppCard(
        padding: const EdgeInsets.symmetric(horizontal: Insets.md, vertical: Insets.sm),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(Radii.sm),
              ),
              child: Icon(icon, color: color, size: 18),
            ),
            const SizedBox(width: Insets.md),
            Expanded(child: Text(label, style: const TextStyle(fontWeight: FontWeight.w600))),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(Radii.pill),
              ),
              child: Text('$count', style: TextStyle(fontWeight: FontWeight.bold, color: color.withValues(alpha: 0.8))),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLastResultCard(SyncResult result, AppSurface s) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                result.success ? Icons.check_circle : Icons.error,
                color: result.success ? Colors.green : Colors.red,
              ),
              const SizedBox(width: Insets.md),
              Expanded(
                child: Text(
                  result.message,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: result.success ? Colors.green.shade800 : Colors.red.shade800,
                  ),
                ),
              ),
            ],
          ),
          if (result.totalSynced > 0 || result.totalFailed > 0) ...[
            const SizedBox(height: Insets.md),
            const Divider(),
            const SizedBox(height: Insets.md),
            if (result.syncedOrders > 0) _buildResultItem('Commandes synchronisées', result.syncedOrders, Colors.green, s),
            if (result.syncedPurchases > 0) _buildResultItem('Achats synchronisés', result.syncedPurchases, Colors.green, s),
            if (result.syncedTransfers > 0) _buildResultItem('Transferts synchronisés', result.syncedTransfers, Colors.green, s),
            if (result.syncedInventories > 0) _buildResultItem('Inventaires synchronisés', result.syncedInventories, Colors.green, s),
            if (result.failedOrders > 0) _buildResultItem('Commandes échouées', result.failedOrders, Colors.red, s),
            if (result.failedPurchases > 0) _buildResultItem('Achats échoués', result.failedPurchases, Colors.red, s),
            if (result.failedTransfers > 0) _buildResultItem('Transferts échoués', result.failedTransfers, Colors.red, s),
            if (result.failedInventories > 0) _buildResultItem('Inventaires échoués', result.failedInventories, Colors.red, s),
          ],
        ],
      ),
    );
  }

  Widget _buildResultItem(String label, int count, Color color, AppSurface s) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: s.muted, fontSize: 13)),
          Text('$count', style: TextStyle(fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }
}
