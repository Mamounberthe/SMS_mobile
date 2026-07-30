import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/transfer.dart';
import '../services/api_client.dart';
import '../services/transfer_service.dart';
import '../services/offline_service.dart';
import '../theme.dart';
import '../widgets/app_card.dart';
import '../widgets/empty_state.dart';
import '../widgets/page_header.dart';
import '../widgets/responsive.dart';
import '../widgets/skeleton.dart';
import '../widgets/status_chip.dart';
import 'create_transfer_screen.dart';
import 'transfer_detail_screen.dart';

/// Transferts — corps hébergé dans AppShell (pas de Scaffold propre).
class TransfersScreen extends StatefulWidget {
  const TransfersScreen({super.key});

  @override
  State<TransfersScreen> createState() => _TransfersScreenState();
}

class _TransfersScreenState extends State<TransfersScreen> {
  late final TransferService _service;
  final List<Transfer> _items = [];
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _service = TransferService(context.read<ApiClient>());
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await _service.list();
      if (mounted) {
        setState(() {
          _items
            ..clear()
            ..addAll(res.items);
        });
      }
      // Mettre à jour le cache pour usage hors-ligne
      final offline = context.read<OfflineService>();
      await offline.cacheTransfers(res.items);
    } catch (e) {
      // En cas d'erreur, essayer de charger depuis le cache
      if (_items.isEmpty) {
        try {
          final offline = context.read<OfflineService>();
          final cached = await offline.getCachedTransfers();
          if (cached.isNotEmpty) {
            setState(() {
              _items
                ..clear()
                ..addAll(cached);
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
      setState(() => _loading = false);
    }
  }

  Future<void> _openCreate() async {
    final created = await Navigator.of(context)
        .push<bool>(MaterialPageRoute(builder: (_) => const CreateTransferScreen()));
    if (created == true) _load();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(Insets.xl),
          children: [
            PageHeader(
              title: 'Transferts',
              actions: [
                FilledButton.icon(
                  onPressed: _openCreate,
                  icon: const Icon(Icons.add),
                  label: const Text('Nouveau'),
                ),
              ],
            ),
            ..._buildContent(context),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildContent(BuildContext context) {
    if (_loading && _items.isEmpty) {
      return const [SkeletonList(padding: EdgeInsets.zero)];
    }
    if (_error != null && _items.isEmpty) {
      return [
        Padding(
          padding: const EdgeInsets.only(top: Insets.xxl),
          child: EmptyState(
            icon: Icons.cloud_off,
            message: _error!,
            actionLabel: 'Réessayer',
            onAction: _load,
          ),
        ),
      ];
    }
    if (_items.isEmpty) {
      return [
        Padding(
          padding: const EdgeInsets.only(top: Insets.xxl),
          child: EmptyState(
            icon: Icons.swap_horiz,
            message: 'Aucun transfert.',
            actionLabel: 'Nouveau',
            onAction: _openCreate,
          ),
        ),
      ];
    }

    return [
      ResponsiveWrap(children: [for (final t in _items) _transferCard(context, t)]),
    ];
  }

  Widget _transferCard(BuildContext context, Transfer t) {
    final s = AppSurface.of(context);
    final info = transferStatusInfo(t.status);
    return AppCard(
      onTap: () async {
        await Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => TransferDetailScreen(transferId: t.id)));
        _load();
      },
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.brand.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(Radii.sm),
            ),
            child: Icon(
              t.isReturn ? Icons.assignment_return : Icons.swap_horiz,
              color: AppColors.brand,
              size: 20,
            ),
          ),
          const SizedBox(width: Insets.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(t.reference,
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                const SizedBox(height: 2),
                Text(
                  '${t.fromName ?? t.fromLocationId} → ${t.toName ?? t.toLocationId}',
                  style: TextStyle(color: s.muted, fontSize: 13),
                ),
              ],
            ),
          ),
          const SizedBox(width: Insets.sm),
          StatusChip(label: info.label, color: info.color),
        ],
      ),
    );
  }
}
