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

/// Bouton d'action rapide global (présent sur tous les écrans).
/// Ouvre un menu des créations les plus courantes, selon le rôle.
class QuickCreateFab extends StatelessWidget {
  /// Navigateur de la zone de contenu (tablette/desktop). Quand il est fourni,
  /// les écrans s'ouvrent dedans pour laisser la barre latérale visible ;
  /// sinon (mobile) ils s'ouvrent en plein écran.
  final GlobalKey<NavigatorState>? contentNavigator;
  const QuickCreateFab({super.key, this.contentNavigator});

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton(
      tooltip: 'Créer / rechercher',
      onPressed: () => _showMenu(context),
      child: const Icon(Icons.add),
    );
  }

  void _showMenu(BuildContext context) {
    final role = context.read<AuthProvider>().user?.role;
    final isGlobal = role == 'admin' || role == 'director';
    final isDepot = isGlobal || role == 'storekeeper';
    final isStore = isGlobal || role == 'store_manager';
    final s = AppSurface.of(context);

    // rootNav : ferme la feuille. targetNav : où pousser les écrans.
    final rootNav = Navigator.of(context);
    final targetNav = contentNavigator?.currentState ?? rootNav;

    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(Insets.xl, 0, Insets.xl, Insets.sm),
              child: Text('Actions rapides',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: s.muted)),
            ),
            if (isStore)
              _tile(rootNav, targetNav, Icons.add_shopping_cart_rounded, Colors.indigo, 'Nouvelle commande',
                  (_) => const CreateOrderScreen()),
            if (isDepot)
              _tile(rootNav, targetNav, Icons.local_shipping_rounded, Colors.purple, 'Nouvel achat',
                  (_) => const CreatePurchaseScreen()),
            if (isDepot || isStore)
              _tile(rootNav, targetNav, Icons.swap_horiz_rounded, Colors.teal, 'Nouveau transfert',
                  (_) => const CreateTransferScreen()),
            if (isDepot || isStore)
              _tile(rootNav, targetNav, Icons.assignment_return_rounded, Colors.brown, 'Retour vers le dépôt',
                  (_) => const CreateTransferScreen(initialIsReturn: true)),
            if (isDepot || isStore)
              _tile(rootNav, targetNav, Icons.fact_check_rounded, Colors.orange, 'Nouvel inventaire',
                  (_) => const CreateInventoryScreen()),
            const Divider(height: 1),
            _tile(rootNav, targetNav, Icons.qr_code_scanner_rounded, AppColors.brand,
                'Chercher / scanner un produit', null, isScan: true),
            const SizedBox(height: Insets.sm),
          ],
        ),
      ),
    );
  }

  Widget _tile(NavigatorState rootNav, NavigatorState targetNav, IconData icon, Color color,
      String label, WidgetBuilder? builder,
      {bool isScan = false}) {
    return ListTile(
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(color: color.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(Radii.sm)),
        child: Icon(icon, color: color, size: 22),
      ),
      title: Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
      onTap: () async {
        rootNav.pop(); // ferme le menu
        if (isScan) {
          final result = await targetNav
              .push(MaterialPageRoute(builder: (_) => const ProductPickerScreen()));
          if (result is Product && targetNav.mounted) {
            targetNav.push(MaterialPageRoute(builder: (_) => ProductDetailScreen(product: result)));
          }
          return;
        }
        if (builder != null) {
          await targetNav.push(MaterialPageRoute(builder: builder));
        }
      },
    );
  }
}
