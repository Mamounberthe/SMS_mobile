import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/purchase.dart';
import '../services/api_client.dart';
import '../services/purchase_service.dart';
import '../services/offline_service.dart';
import '../theme.dart';
import '../widgets/responsive.dart';
import '../widgets/skeleton.dart';
import '../utils/format.dart';
import '../widgets/app_card.dart';
import '../widgets/empty_state.dart';
import '../widgets/page_header.dart';
import '../widgets/status_chip.dart';
import 'create_purchase_screen.dart';
import 'purchase_detail_screen.dart';

/// Achats / Réceptions — corps hébergé dans AppShell (pas de Scaffold propre).
class PurchasesScreen extends StatefulWidget {
  const PurchasesScreen({super.key});

  @override
  State<PurchasesScreen> createState() => _PurchasesScreenState();
}

class _PurchasesScreenState extends State<PurchasesScreen> {
  late final PurchaseService _service;
  final List<Purchase> _items = [];
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _service = PurchaseService(context.read<ApiClient>());
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
      await offline.cachePurchases(res.items);
    } catch (e) {
      // En cas d'erreur, essayer de charger depuis le cache
      if (_items.isEmpty) {
        try {
          final offline = context.read<OfflineService>();
          final cached = await offline.getCachedPurchases();
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
        .push<bool>(MaterialPageRoute(builder: (_) => const CreatePurchaseScreen()));
    if (created == true) _load();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(Insets.xl, Insets.xl, Insets.xl, 0),
            child: PageHeader(
              title: 'Achats',
              subtitle: 'Réceptions au dépôt central',
              actions: [
                FilledButton.icon(
                  onPressed: _openCreate,
                  icon: const Icon(Icons.add),
                  label: const Text('Nouvel achat'),
                ),
              ],
            ),
          ),
          Expanded(child: _buildBody(context)),
        ],
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_loading && _items.isEmpty) {
      return const SkeletonList();
    }
    if (_error != null && _items.isEmpty) {
      return EmptyState(
        icon: Icons.cloud_off,
        message: _error!,
        actionLabel: 'Réessayer',
        onAction: _load,
      );
    }
    if (_items.isEmpty) {
      return EmptyState(
        icon: Icons.shopping_cart_outlined,
        message: 'Aucun achat.',
        actionLabel: 'Nouvel achat',
        onAction: _openCreate,
      );
    }

    final s = AppSurface.of(context);
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(Insets.xl, Insets.lg, Insets.xl, Insets.xl),
        children: [
          ResponsiveWrap(children: [for (final p in _items) _purchaseCard(p, s)]),
        ],
      ),
    );
  }

  Widget _purchaseCard(dynamic p, AppSurface s) {
    final info = purchaseStatusInfo(p.status);
    return AppCard(
      onTap: () async {
        await Navigator.of(context)
            .push(MaterialPageRoute(builder: (_) => PurchaseDetailScreen(purchaseId: p.id)));
        _load();
      },
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.brand.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(Radii.md),
            ),
            child: const Icon(Icons.shopping_cart, color: AppColors.brand),
          ),
          const SizedBox(width: Insets.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(p.reference, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                const SizedBox(height: 2),
                Text('${p.supplierName ?? 'Fournisseur'} · ${fcfa(p.totalAmount)}',
                    style: TextStyle(color: s.muted, fontSize: 13)),
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
