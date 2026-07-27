import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../models/inventory.dart';
import '../services/api_client.dart';
import '../services/inventory_service.dart';
import '../theme.dart';
import '../widgets/app_card.dart';
import '../widgets/empty_state.dart';
import '../widgets/responsive.dart';
import '../widgets/skeleton.dart';
import '../widgets/status_chip.dart';

const _reasons = {
  'loss': 'Perte',
  'theft': 'Vol',
  'error': 'Erreur',
  'expired': 'Expiré',
  'other': 'Autre',
};

class InventoryDetailScreen extends StatefulWidget {
  final int inventoryId;
  const InventoryDetailScreen({super.key, required this.inventoryId});

  @override
  State<InventoryDetailScreen> createState() => _InventoryDetailScreenState();
}

class _InventoryDetailScreenState extends State<InventoryDetailScreen> {
  late final InventoryService _service;
  Inventory? _inv;
  bool _loading = true;
  bool _busy = false;

  final Map<int, TextEditingController> _counted = {};
  final Map<int, String?> _reason = {};

  @override
  void initState() {
    super.initState();
    _service = InventoryService(context.read<ApiClient>());
    _load();
  }

  @override
  void dispose() {
    for (final c in _counted.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final inv = await _service.get(widget.inventoryId);
      for (final it in inv.items) {
        _counted.putIfAbsent(
          it.id,
          () => TextEditingController(text: '${it.countedQuantity ?? it.systemQuantity}'),
        );
        _reason.putIfAbsent(it.id, () => it.reason);
      }
      setState(() => _inv = inv);
    } catch (_) {
      // ignore : l'écran affiche « Introuvable »
    } finally {
      setState(() => _loading = false);
    }
  }

  bool get _closed => _inv?.status == 'closed';

  Future<void> _saveCounts() async {
    final items = <Map<String, dynamic>>[];
    for (final it in _inv!.items) {
      final txt = _counted[it.id]?.text.trim() ?? '';
      if (txt.isEmpty) continue;
      items.add({
        'inventory_item_id': it.id,
        'counted_quantity': int.tryParse(txt) ?? it.systemQuantity,
        if (_reason[it.id] != null) 'reason': _reason[it.id],
      });
    }
    if (items.isEmpty) return;
    setState(() => _busy = true);
    try {
      final inv = await _service.count(widget.inventoryId, items);
      setState(() => _inv = inv);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Comptage enregistré.')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(ApiClient.errorMessage(e)), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _close() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Clôturer l'inventaire ?"),
        content: const Text('Les écarts seront appliqués au stock (ajustements). Action définitive.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Retour')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Clôturer')),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => _busy = true);
    try {
      final inv = await _service.close(widget.inventoryId);
      setState(() => _inv = inv);
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Inventaire clôturé, stock ajusté.')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(ApiClient.errorMessage(e)), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final inv = _inv;
    return Scaffold(
      appBar: AppBar(title: Text(inv?.reference ?? 'Inventaire')),
      body: _loading
          ? const SkeletonList()
          : inv == null
              ? const EmptyState(icon: Icons.fact_check_outlined, message: 'Inventaire introuvable.')
              : ListView(
                  padding: const EdgeInsets.all(Insets.lg),
                  children: [
                    AppCard(
                      child: Row(
                        children: [
                          Expanded(
                              child: Text(inv.locationName ?? 'Lieu #${inv.locationId}',
                                  style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600))),
                          StatusChip(
                              label: inventoryStatusInfo(inv.status).label,
                              color: inventoryStatusInfo(inv.status).color),
                        ],
                      ),
                    ),
                    const SizedBox(height: Insets.lg),
                    ResponsiveWrap(
                      minItemWidth: 380,
                      children: [for (final it in inv.items) _itemCard(it)],
                    ),
                    const SizedBox(height: Insets.xxl),
                  ],
                ),
      bottomNavigationBar: (inv == null || _closed) ? null : _actions(),
    );
  }

  Widget _itemCard(InventoryItem it) {
    final s = AppSurface.of(context);

    if (_closed) {
      final diff = it.difference ?? 0;
      return AppCard(
        padding: EdgeInsets.zero,
        child: ListTile(
          title: Text(it.productName ?? 'Produit #${it.productId}'),
          subtitle: Text(
            'Système ${it.systemQuantity} → Compté ${it.countedQuantity ?? '-'}'
            '${it.reason != null ? ' · ${_reasons[it.reason] ?? it.reason}' : ''}',
            style: TextStyle(color: s.muted),
          ),
          trailing: Text(
            diff == 0 ? '0' : (diff > 0 ? '+$diff' : '$diff'),
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 15,
              color: diff == 0 ? s.muted : (diff > 0 ? Colors.green : Colors.red),
            ),
          ),
        ),
      );
    }

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(it.productName ?? 'Produit #${it.productId}',
              style: const TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: Insets.md),
          Row(
            children: [
              Expanded(child: Text('Stock système : ${it.systemQuantity}', style: TextStyle(color: s.muted))),
              SizedBox(
                width: 110,
                child: TextField(
                  controller: _counted[it.id],
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(labelText: 'Compté', isDense: true),
                ),
              ),
            ],
          ),
          const SizedBox(height: Insets.sm),
          DropdownButtonFormField<String?>(
            initialValue: _reason[it.id],
            isDense: true,
            decoration: const InputDecoration(labelText: 'Motif (si écart)', isDense: true),
            items: [
              const DropdownMenuItem<String?>(value: null, child: Text('—')),
              ..._reasons.entries.map((e) => DropdownMenuItem(value: e.key, child: Text(e.value))),
            ],
            onChanged: (v) => setState(() => _reason[it.id] = v),
          ),
        ],
      ),
    );
  }

  Widget _actions() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(Insets.md),
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _busy ? null : _saveCounts,
                icon: const Icon(Icons.save),
                label: const Text('Enregistrer'),
              ),
            ),
            const SizedBox(width: Insets.sm),
            Expanded(
              child: FilledButton.icon(
                onPressed: _busy ? null : _close,
                style: FilledButton.styleFrom(backgroundColor: Colors.green),
                icon: const Icon(Icons.lock),
                label: const Text('Clôturer'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
