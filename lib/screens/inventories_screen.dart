import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/inventory.dart';
import '../services/api_client.dart';
import '../services/inventory_service.dart';
import '../services/offline_service.dart';
import '../theme.dart';
import '../widgets/responsive.dart';
import '../widgets/skeleton.dart';
import '../widgets/app_card.dart';
import '../widgets/empty_state.dart';
import '../widgets/page_header.dart';
import '../widgets/status_chip.dart';
import 'create_inventory_screen.dart';
import 'inventory_detail_screen.dart';

/// Liste des inventaires — corps hébergé dans AppShell (pas de Scaffold propre).
class InventoriesScreen extends StatefulWidget {
  const InventoriesScreen({super.key});

  @override
  State<InventoriesScreen> createState() => _InventoriesScreenState();
}

class _InventoriesScreenState extends State<InventoriesScreen> {
  late final InventoryService _service;
  final List<Inventory> _items = [];
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _service = InventoryService(context.read<ApiClient>());
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
      await offline.cacheInventories(res.items);
    } catch (e) {
      // En cas d'erreur, essayer de charger depuis le cache
      if (_items.isEmpty) {
        try {
          final offline = context.read<OfflineService>();
          final cached = await offline.getCachedInventories();
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
        .push<bool>(MaterialPageRoute(builder: (_) => const CreateInventoryScreen()));
    if (created == true) _load();
  }

  Future<void> _openDetail(Inventory inv) async {
    await Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => InventoryDetailScreen(inventoryId: inv.id)));
    _load();
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
              title: 'Inventaires',
              actions: [
                FilledButton.icon(
                  onPressed: _openCreate,
                  icon: const Icon(Icons.add),
                  label: const Text('Nouvel inventaire'),
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
        icon: Icons.fact_check_outlined,
        message: 'Aucun inventaire.',
        actionLabel: 'Nouvel inventaire',
        onAction: _openCreate,
      );
    }

    final s = AppSurface.of(context);
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(Insets.xl, Insets.lg, Insets.xl, Insets.xl),
        children: [
          ResponsiveWrap(children: [for (final inv in _items) _inventoryCard(inv, s)]),
        ],
      ),
    );
  }

  Widget _inventoryCard(inv, AppSurface s) {
    final info = inventoryStatusInfo(inv.status);
    return AppCard(
      onTap: () => _openDetail(inv),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.brand.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(Radii.md),
            ),
            child: const Icon(Icons.fact_check, color: AppColors.brand),
          ),
          const SizedBox(width: Insets.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(inv.reference, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                const SizedBox(height: 2),
                Text('${inv.locationName ?? inv.locationId} · ${inv.type == 'full' ? 'complet' : 'partiel'}',
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
