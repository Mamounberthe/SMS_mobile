import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/product.dart';
import '../providers/auth_provider.dart';
import '../screens/create_inventory_screen.dart';
import '../screens/create_order_screen.dart';
import '../screens/create_purchase_screen.dart';
import '../screens/create_transfer_screen.dart';
import '../screens/product_detail_screen.dart';
import '../screens/product_picker_screen.dart';
import '../theme.dart';

class _QuickAction {
  final String label;
  final IconData icon;
  final Color color;
  final WidgetBuilder builder;
  const _QuickAction(this.label, this.icon, this.color, this.builder);
}

/// Barre de boutons de raccourcis (actions rapides) — role-aware.
class QuickActions extends StatelessWidget {
  final VoidCallback? onDone;
  const QuickActions({super.key, this.onDone});

  @override
  Widget build(BuildContext context) {
    final role = context.read<AuthProvider>().user?.role;
    final isGlobal = role == 'admin' || role == 'director';
    final isDepot = isGlobal || role == 'storekeeper';
    final isStore = isGlobal || role == 'store_manager';

    final actions = <_QuickAction>[
      if (isStore)
        _QuickAction('Nouvelle commande', Icons.add_shopping_cart_rounded, Colors.indigo,
            (_) => const CreateOrderScreen()),
      if (isDepot)
        _QuickAction('Nouvel achat', Icons.local_shipping_rounded, Colors.purple,
            (_) => const CreatePurchaseScreen()),
      if (isDepot || isStore)
        _QuickAction('Nouveau transfert', Icons.swap_horiz_rounded, Colors.teal,
            (_) => const CreateTransferScreen()),
      if (isDepot || isStore)
        _QuickAction('Nouvel inventaire', Icons.fact_check_rounded, Colors.orange,
            (_) => const CreateInventoryScreen()),
    ];

    return LayoutBuilder(
      builder: (context, c) {
        // 1 colonne étroit, sinon largeur fixe qui s'enroule (Wrap).
        final tileWidth = c.maxWidth < 420
            ? c.maxWidth
            : (c.maxWidth < 720 ? (c.maxWidth - Insets.md) / 2 : 210.0);
        return Wrap(
          spacing: Insets.md,
          runSpacing: Insets.md,
          children: [
            for (final a in actions)
              SizedBox(
                width: tileWidth,
                child: _ActionTile(action: a, onDone: onDone),
              ),
            SizedBox(
              width: tileWidth,
              child: _ScanTile(onDone: onDone),
            ),
          ],
        );
      },
    );
  }
}

class _ActionTile extends StatelessWidget {
  final _QuickAction action;
  final VoidCallback? onDone;
  const _ActionTile({required this.action, this.onDone});

  @override
  Widget build(BuildContext context) {
    final s = AppSurface.of(context);
    return Material(
      color: s.surface,
      borderRadius: BorderRadius.circular(Radii.md),
      child: InkWell(
        borderRadius: BorderRadius.circular(Radii.md),
        onTap: () async {
          final done = await Navigator.of(context).push<bool>(
            MaterialPageRoute(builder: action.builder),
          );
          if (done == true) onDone?.call();
        },
        child: Container(
          padding: const EdgeInsets.all(Insets.md),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(Radii.md),
            border: Border.all(color: s.border),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: action.color.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(Radii.sm),
                ),
                child: Icon(action.icon, color: action.color, size: 22),
              ),
              const SizedBox(width: Insets.md),
              Expanded(
                child: Text(action.label,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ScanTile extends StatelessWidget {
  final VoidCallback? onDone;
  const _ScanTile({this.onDone});

  @override
  Widget build(BuildContext context) {
    final s = AppSurface.of(context);
    return Material(
      color: s.surface,
      borderRadius: BorderRadius.circular(Radii.md),
      child: InkWell(
        borderRadius: BorderRadius.circular(Radii.md),
        onTap: () async {
          final result = await Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const ProductPickerScreen()),
          );
          if (result is Product && context.mounted) {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => ProductDetailScreen(product: result)),
            );
          }
        },
        child: Container(
          padding: const EdgeInsets.all(Insets.md),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(Radii.md),
            border: Border.all(color: s.border),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.brand.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(Radii.sm),
                ),
                child: const Icon(Icons.qr_code_scanner_rounded, color: AppColors.brand, size: 22),
              ),
              const SizedBox(width: Insets.md),
              const Expanded(
                child: Text('Chercher / scanner',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
