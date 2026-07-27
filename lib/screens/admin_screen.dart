import 'package:flutter/material.dart';

import '../theme.dart';
import '../widgets/app_card.dart';
import 'categories_screen.dart';
import 'locations_screen.dart';
import 'reports_screen.dart';
import 'suppliers_screen.dart';
import 'users_screen.dart';

class _AdminItem {
  final String label;
  final String subtitle;
  final IconData icon;
  final Color color;
  final WidgetBuilder? builder; // null = à venir
  const _AdminItem(this.label, this.subtitle, this.icon, this.color, this.builder);
}

/// Hub d'administration : accès aux sections de configuration.
class AdminScreen extends StatelessWidget {
  const AdminScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = AppSurface.of(context);
    final items = <_AdminItem>[
      _AdminItem('Catégories', 'Gérer les catégories de produits', Icons.category_rounded, Colors.teal,
          (_) => const CategoriesScreen()),
      _AdminItem('Fournisseurs', 'Gérer les fournisseurs + historique', Icons.business_rounded, Colors.indigo,
          (_) => const SuppliersScreen()),
      _AdminItem('Utilisateurs', 'Comptes & rôles', Icons.people_rounded, Colors.purple,
          (_) => const UsersScreen()),
      _AdminItem('Lieux', 'Dépôt & boutiques', Icons.store_rounded, Colors.orange,
          (_) => const LocationsScreen()),
      _AdminItem('Rapports', 'Valeur stock, mouvements, péremptions', Icons.bar_chart_rounded, Colors.blue,
          (_) => const ReportsScreen()),
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('Administration')),
      body: ListView.separated(
        padding: const EdgeInsets.all(Insets.lg),
        itemCount: items.length,
        separatorBuilder: (_, _) => const SizedBox(height: Insets.sm),
        itemBuilder: (context, i) {
          final it = items[i];
          final enabled = it.builder != null;
          return AppCard(
            onTap: enabled
                ? () => Navigator.of(context).push(MaterialPageRoute(builder: it.builder!))
                : null,
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: it.color.withValues(alpha: enabled ? 0.14 : 0.06),
                    borderRadius: BorderRadius.circular(Radii.md),
                  ),
                  child: Icon(it.icon, color: enabled ? it.color : s.muted),
                ),
                const SizedBox(width: Insets.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(it.label, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15, color: enabled ? s.text : s.muted)),
                      const SizedBox(height: 2),
                      Text(it.subtitle, style: TextStyle(color: s.muted, fontSize: 13)),
                    ],
                  ),
                ),
                Icon(enabled ? Icons.chevron_right : Icons.lock_outline, color: s.muted, size: 20),
              ],
            ),
          );
        },
      ),
    );
  }
}
