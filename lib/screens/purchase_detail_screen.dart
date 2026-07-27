import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/purchase.dart';
import '../services/api_client.dart';
import '../services/purchase_service.dart';
import '../theme.dart';
import '../utils/format.dart';
import '../widgets/app_card.dart';
import '../widgets/confirm_dialog.dart';
import '../widgets/empty_state.dart';
import '../widgets/responsive.dart';
import '../widgets/skeleton.dart';
import '../widgets/status_chip.dart';

class PurchaseDetailScreen extends StatefulWidget {
  final int purchaseId;
  const PurchaseDetailScreen({super.key, required this.purchaseId});

  @override
  State<PurchaseDetailScreen> createState() => _PurchaseDetailScreenState();
}

class _PurchaseDetailScreenState extends State<PurchaseDetailScreen> {
  late final PurchaseService _service;
  Purchase? _p;
  bool _loading = true;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _service = PurchaseService(context.read<ApiClient>());
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final p = await _service.get(widget.purchaseId);
      setState(() => _p = p);
    } catch (_) {
      // ignore : l'écran affiche « Achat introuvable »
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _run(Future<Purchase> Function() call, String okMsg) async {
    setState(() => _busy = true);
    try {
      final p = await call();
      setState(() => _p = p);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(okMsg)));
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
    final p = _p;
    return Scaffold(
      appBar: AppBar(title: Text(p?.reference ?? 'Achat')),
      body: _loading
          ? const SkeletonList()
          : p == null
              ? const EmptyState(icon: Icons.receipt_long, message: 'Achat introuvable.')
              : ListView(
                  padding: const EdgeInsets.all(Insets.lg),
                  children: [
                    TwoPane(
                      left: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [_header(context, p)],
                      ),
                      right: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text('Articles', style: Theme.of(context).textTheme.titleSmall),
                          const SizedBox(height: Insets.sm),
                          for (final it in p.items) ...[
                            _itemCard(context, it),
                            if (it != p.items.last) const SizedBox(height: Insets.sm),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: Insets.xxl),
                  ],
                ),
      bottomNavigationBar: (p == null) ? null : _actions(p),
    );
  }

  Widget _header(BuildContext context, Purchase p) {
    final s = AppSurface.of(context);
    final info = purchaseStatusInfo(p.status);
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  p.supplierName ?? 'Fournisseur #${p.supplierId}',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                ),
              ),
              const SizedBox(width: Insets.sm),
              StatusChip(label: info.label, color: info.color),
            ],
          ),
          const SizedBox(height: Insets.xs),
          Text('Total : ${fcfa(p.totalAmount)}', style: TextStyle(color: s.muted)),
        ],
      ),
    );
  }

  Widget _itemCard(BuildContext context, PurchaseItem it) {
    final s = AppSurface.of(context);
    return AppCard(
      padding: EdgeInsets.zero,
      child: ListTile(
        title: Text(it.productName ?? 'Produit #${it.productId}'),
        subtitle: Text(
          [
            'Cmd : ${it.quantity}',
            if (it.receivedQuantity > 0) 'Reçu : ${it.receivedQuantity}',
            if (it.lotNumber != null) 'Lot : ${it.lotNumber}',
            if (it.expiryDate != null) 'Exp : ${it.expiryDate}',
          ].join(' · '),
          style: TextStyle(color: s.muted),
        ),
        trailing: Text(fcfa(it.unitPrice), style: TextStyle(fontSize: 12, color: s.muted)),
      ),
    );
  }

  Widget? _actions(Purchase p) {
    if (p.status == 'received' || p.status == 'cancelled') return null;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(Insets.md),
        child: Row(
          children: [
            Expanded(
              child: FilledButton.icon(
                onPressed: _busy
                    ? null
                    : () async {
                        final ok = await confirmAction(
                          context,
                          title: 'Réceptionner cet achat ?',
                          message: 'Le stock du dépôt sera augmenté (les lots seront créés). Action définitive.',
                          confirmLabel: 'Réceptionner',
                        );
                        if (ok) _run(() => _service.receive(p.id), 'Achat réceptionné (stock mis à jour).');
                      },
                style: FilledButton.styleFrom(backgroundColor: Colors.green),
                icon: const Icon(Icons.inventory_2),
                label: const Text('Réceptionner'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
