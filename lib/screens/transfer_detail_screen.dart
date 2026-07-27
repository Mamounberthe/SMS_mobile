import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/transfer.dart';
import '../services/api_client.dart';
import '../services/transfer_service.dart';
import '../theme.dart';
import '../widgets/confirm_dialog.dart';
import '../widgets/skeleton.dart';
import '../utils/logger.dart';
import '../widgets/app_card.dart';
import '../widgets/empty_state.dart';
import '../widgets/responsive.dart';
import '../widgets/status_chip.dart';

class TransferDetailScreen extends StatefulWidget {
  final int transferId;
  const TransferDetailScreen({super.key, required this.transferId});

  @override
  State<TransferDetailScreen> createState() => _TransferDetailScreenState();
}

class _TransferDetailScreenState extends State<TransferDetailScreen> {
  late final TransferService _service;
  Transfer? _t;
  bool _loading = true;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _service = TransferService(context.read<ApiClient>());
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final t = await _service.get(widget.transferId);
      setState(() => _t = t);
    } catch (e) {
      AppLogger.e('Erreur lors du chargement du transfert', error: e);
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _run(String action) async {
    const messages = {
      'dispatch': 'Le stock de la source sera diminué (expédition). Continuer ?',
      'receive': 'Le stock de la destination sera augmenté (réception). Continuer ?',
      'cancel': 'Annuler ce transfert ? Action définitive.',
    };
    if (messages.containsKey(action)) {
      final ok = await confirmAction(context,
          title: 'Confirmer', message: messages[action]!, danger: action == 'cancel');
      if (!ok) return;
    }
    setState(() => _busy = true);
    try {
      final t = await _service.action(widget.transferId, action);
      setState(() => _t = t);
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Transfert ${transferStatusInfo(t.status).label.toLowerCase()}.')));
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
    final t = _t;
    return Scaffold(
      appBar: AppBar(title: Text(t?.reference ?? 'Transfert')),
      body: _loading
          ? const SkeletonList()
          : t == null
              ? const EmptyState(icon: Icons.search_off, message: 'Introuvable')
              : ListView(
                  padding: const EdgeInsets.all(Insets.lg),
                  children: [
                    TwoPane(
                      left: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          AppCard(
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '${t.fromName ?? t.fromLocationId}  →  ${t.toName ?? t.toLocationId}',
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleMedium
                                            ?.copyWith(fontWeight: FontWeight.w600),
                                      ),
                                      if (t.isReturn)
                                        const Padding(
                                          padding: EdgeInsets.only(top: Insets.xs),
                                          child: Text(
                                            'Retour vers le dépôt',
                                            style: TextStyle(
                                                color: AppColors.brand, fontWeight: FontWeight.w500),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: Insets.sm),
                                StatusChip(
                                    label: transferStatusInfo(t.status).label,
                                    color: transferStatusInfo(t.status).color),
                              ],
                            ),
                          ),
                        ],
                      ),
                      right: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text('Articles', style: Theme.of(context).textTheme.titleSmall),
                          const SizedBox(height: Insets.sm),
                          for (final it in t.items) ...[
                            AppCard(
                              padding: EdgeInsets.zero,
                              child: ListTile(
                                title: Text(it.productName ?? 'Produit #${it.productId}'),
                                subtitle: it.quantityReceived != null
                                    ? Text('Reçu : ${it.quantityReceived}')
                                    : null,
                                trailing: Text('x${it.quantity}',
                                    style: const TextStyle(fontWeight: FontWeight.bold)),
                              ),
                            ),
                            if (it != t.items.last) const SizedBox(height: Insets.sm),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
      bottomNavigationBar: (t == null) ? null : _actions(t),
    );
  }

  Widget? _actions(Transfer t) {
    final buttons = <Widget>[];
    if (t.status == 'draft') {
      buttons.add(Expanded(
        child: FilledButton.icon(
          onPressed: _busy ? null : () => _run('dispatch'),
          style: FilledButton.styleFrom(backgroundColor: Colors.purple),
          icon: const Icon(Icons.local_shipping),
          label: const Text('Expédier'),
        ),
      ));
      buttons.add(const SizedBox(width: Insets.sm));
      buttons.add(Expanded(
        child: OutlinedButton.icon(
          onPressed: _busy ? null : () => _run('cancel'),
          icon: const Icon(Icons.cancel, color: Colors.red),
          label: const Text('Annuler', style: TextStyle(color: Colors.red)),
        ),
      ));
    } else if (t.status == 'dispatched') {
      buttons.add(Expanded(
        child: FilledButton.icon(
          onPressed: _busy ? null : () => _run('receive'),
          style: FilledButton.styleFrom(backgroundColor: Colors.green),
          icon: const Icon(Icons.inventory_2),
          label: const Text('Réceptionner'),
        ),
      ));
    }
    if (buttons.isEmpty) return null;
    return SafeArea(
        child: Padding(padding: const EdgeInsets.all(Insets.md), child: Row(children: buttons)));
  }
}
