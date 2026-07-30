import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../screens/admin_screen.dart';
import '../screens/dashboard_screen.dart';
import '../screens/global_search_screen.dart';
import '../screens/inventories_screen.dart';
import '../screens/notifications_screen.dart';
import '../screens/orders_screen.dart';
import '../screens/products_screen.dart';
import '../screens/purchases_screen.dart';
import '../screens/transfers_screen.dart';
import '../screens/sync_status_screen.dart';
import '../screens/settings_screen.dart';
import '../screens/analytics_screen.dart';
import '../theme.dart';
import '../theme_controller.dart';
import 'quick_create_fab.dart';

class _Destination {
  final String label;
  final IconData icon;
  final Widget screen;
  const _Destination(this.label, this.icon, this.screen);
}

const _destinations = <_Destination>[
  _Destination('Tableau de bord', Icons.dashboard_rounded, DashboardScreen()),
  _Destination('Produits', Icons.inventory_2_rounded, ProductsScreen()),
  _Destination('Commandes', Icons.receipt_long_rounded, OrdersScreen()),
  _Destination('Transferts', Icons.swap_horiz_rounded, TransfersScreen()),
  _Destination('Achats', Icons.shopping_cart_rounded, PurchasesScreen()),
  _Destination('Inventaires', Icons.fact_check_rounded, InventoriesScreen()),
  _Destination('Notifications', Icons.notifications_rounded, NotificationsScreen()),
  _Destination('Synchronisation', Icons.sync_rounded, SyncStatusScreen()),
  _Destination('Statistiques', Icons.bar_chart_rounded, AnalyticsScreen()),
  _Destination('Paramètres', Icons.settings_rounded, SettingsScreen()),
];

// Seuils responsive.
const double _kSidebar = 1000; // >= : barre latérale complète (bureau / tablette paysage)
const double _kRail = 600; //     >= : rail toujours visible (tablette portrait)

/// Coquille responsive à 3 niveaux :
///  - large    : barre latérale avec libellés,
///  - tablette : rail toujours visible (accès en 1 tap, grandes cibles),
///  - téléphone: AppBar + tiroir.
class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  // Indices nommés pour éviter la désynchronisation
  static const int _idxTransfers = 3;
  static const int _idxPurchases = 4;
  static const int _idxInventories = 5;
  static const int _idxNotifications = 6;
  static const int _idxSync = 7;
  static const int _idxAnalytics = 8;
  static const int _idxSettings = 9;

  // Index de la destination active. Un ValueNotifier permet de rafraîchir le
  // contenu (hébergé dans un Navigator imbriqué) sans régénérer sa route racine.
  final ValueNotifier<int> _index = ValueNotifier<int>(0);
  // Chargement paresseux : on ne construit (et ne charge les données) que
  // des écrans déjà ouverts. Au démarrage, seul le tableau de bord charge.
  final Set<int> _visited = {0};

  // Navigateur propre à la zone de contenu (tablette / desktop) : les écrans de
  // détail et les formulaires s'y empilent, donc la barre latérale reste fixe.
  final GlobalKey<NavigatorState> _contentNav = GlobalKey<NavigatorState>();

  @override
  void dispose() {
    _index.dispose();
    super.dispose();
  }

  void _select(int i) {
    _visited.add(i);
    _index.value = i; // rafraîchit le contenu du Navigator imbriqué
    // Referme un éventuel écran de détail/formulaire ouvert dans le contenu.
    _contentNav.currentState?.popUntil((r) => r.isFirst);
    setState(() {}); // met à jour la sélection (barre latérale / rail / bas)
  }

  // Limite la largeur du contenu sur grands écrans (lecture confortable, look premium).
  Widget _constrain(Widget child) => Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 1280), child: child),
      );

  /// Pile des destinations (chargement paresseux via `_visited`).
  Widget _stack() => IndexedStack(
        index: _index.value,
        children: [
          for (var i = 0; i < _destinations.length; i++)
            _visited.contains(i) ? _destinations[i].screen : const SizedBox.shrink(),
        ],
      );

  /// Zone de contenu pour tablette / desktop : un Navigator imbriqué dont la
  /// route racine affiche la destination courante. Détails et formulaires s'y
  /// empilent, laissant la navigation latérale toujours visible.
  Widget _contentPane() => Navigator(
        key: _contentNav,
        onGenerateRoute: (_) => MaterialPageRoute(
          builder: (_) => _constrain(
            ValueListenableBuilder<int>(
              valueListenable: _index,
              builder: (_, _, _) => _stack(),
            ),
          ),
        ),
      );

  void _openAdmin() {
    // Ouvre l'admin dans la zone de contenu si disponible (tablette/desktop),
    // sinon en plein écran (mobile).
    final nav = _contentNav.currentState ?? Navigator.of(context);
    nav.push(MaterialPageRoute(builder: (_) => const AdminScreen()));
  }

  /// Feuille « Plus » du mobile : modules secondaires + admin + profil.
  void _showMoreSheet(BuildContext context, bool isAdmin) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) {
          String searchQuery = '';
          return SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.all(Insets.md),
                  child: TextField(
                    decoration: const InputDecoration(
                      hintText: 'Rechercher...',
                      prefixIcon: Icon(Icons.search),
                      contentPadding: EdgeInsets.symmetric(horizontal: Insets.md, vertical: Insets.sm),
                    ),
                    onChanged: (value) => setLocal(() => searchQuery = value.toLowerCase()),
                  ),
                ),
                Flexible(
                  child: ListView(
                    shrinkWrap: true,
                    children: [
                      // Écrans principaux supplémentaires
                      for (final i in const [_idxTransfers, _idxPurchases, _idxInventories])
                        if (_destinations[i].label.toLowerCase().contains(searchQuery))
                          ListTile(
                            leading: Icon(_destinations[i].icon, color: AppColors.brand),
                            title: Text(_destinations[i].label),
                            selected: _index.value == i,
                            onTap: () {
                              Navigator.pop(ctx);
                              _select(i);
                            },
                          ),
                      if (searchQuery.isEmpty) const Divider(height: 1),
                      // Nouvelles fonctionnalités
                      if ('synchronisation'.contains(searchQuery))
                        ListTile(
                          leading: const Icon(Icons.sync_rounded, color: AppColors.brand),
                          title: const Text('Synchronisation'),
                          selected: _index.value == _idxSync,
                          onTap: () {
                            Navigator.pop(ctx);
                            _select(_idxSync);
                          },
                        ),
                      if ('statistiques'.contains(searchQuery))
                        ListTile(
                          leading: const Icon(Icons.bar_chart_rounded, color: AppColors.brand),
                          title: const Text('Statistiques'),
                          selected: _index.value == _idxAnalytics,
                          onTap: () {
                            Navigator.pop(ctx);
                            _select(_idxAnalytics);
                          },
                        ),
                      if ('paramètres'.contains(searchQuery) || 'settings'.contains(searchQuery))
                        ListTile(
                          leading: const Icon(Icons.settings_rounded, color: AppColors.brand),
                          title: const Text('Paramètres'),
                          selected: _index.value == _idxSettings,
                          onTap: () {
                            Navigator.pop(ctx);
                            _select(_idxSettings);
                          },
                        ),
                      if (searchQuery.isEmpty) const Divider(height: 1),
                      // Admin
                      if (isAdmin && ('administration'.contains(searchQuery) || 'admin'.contains(searchQuery)))
                        ListTile(
                          leading: const Icon(Icons.admin_panel_settings_outlined, color: AppColors.brand),
                          title: const Text('Administration'),
                          onTap: () {
                            Navigator.pop(ctx);
                            _openAdmin();
                          },
                        ),
                      if (searchQuery.isEmpty) const Divider(height: 1),
                      const _UserFooter(),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    final role = context.watch<AuthProvider>().user?.role;
    final isAdmin = role == 'admin' || role == 'director';

    // Bureau / tablette paysage → barre latérale complète (fixe) + contenu à droite.
    if (w >= _kSidebar) {
      return Scaffold(
        body: Row(
          children: [
            _Sidebar(index: _index.value, onSelect: _select, onAdmin: isAdmin ? _openAdmin : null),
            Expanded(child: _contentPane()),
          ],
        ),
      );
    }

    // Tablette portrait → rail toujours visible (fixe) + contenu à droite.
    if (w >= _kRail) {
      return Scaffold(
        body: Row(
          children: [
            _Rail(index: _index.value, onSelect: _select, onAdmin: isAdmin ? _openAdmin : null),
            Expanded(child: _contentPane()),
          ],
        ),
      );
    }

    // Téléphone → AppBar + barre de navigation du bas (pas de nav imbriqué :
    // les écrans s'ouvrent en plein écran, comportement attendu sur mobile).
    const bottomDest = [0, 1, 2, _idxNotifications]; // Accueil, Produits, Commandes, Alertes
    final bottomIndex = bottomDest.indexOf(_index.value);
    return Scaffold(
      floatingActionButton: const QuickCreateFab(),
      appBar: AppBar(
        title: const _BrandMark(compact: true),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const GlobalSearchScreen()),
              );
            },
          ),
          const _ThemeToggle(),
          const SizedBox(width: Insets.sm),
        ],
      ),
      body: _stack(),
      bottomNavigationBar: NavigationBar(
        selectedIndex: bottomIndex >= 0 ? bottomIndex : _idxPurchases,
        onDestinationSelected: (i) {
          if (i < bottomDest.length) {
            _select(bottomDest[i]);
          } else {
            _showMoreSheet(context, isAdmin);
          }
        },
        destinations: const [
          NavigationDestination(icon: Icon(Icons.dashboard_outlined), selectedIcon: Icon(Icons.dashboard), label: 'Accueil'),
          NavigationDestination(icon: Icon(Icons.inventory_2_outlined), selectedIcon: Icon(Icons.inventory_2), label: 'Produits'),
          NavigationDestination(icon: Icon(Icons.receipt_long_outlined), selectedIcon: Icon(Icons.receipt_long), label: 'Commandes'),
          NavigationDestination(icon: Icon(Icons.notifications_outlined), selectedIcon: Icon(Icons.notifications), label: 'Alertes'),
          NavigationDestination(icon: Icon(Icons.more_horiz), label: 'Plus'),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Barre latérale (large)
// ---------------------------------------------------------------------------
class _Sidebar extends StatelessWidget {
  final int index;
  final ValueChanged<int> onSelect;
  final VoidCallback? onAdmin;
  const _Sidebar({required this.index, required this.onSelect, this.onAdmin});

  @override
  Widget build(BuildContext context) {
    final s = AppSurface.of(context);
    return Container(
      width: 252,
      decoration: BoxDecoration(
        color: s.surface,
        border: Border(right: BorderSide(color: s.border)),
      ),
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(Insets.xl, Insets.xl, Insets.lg, Insets.lg),
              child: Row(
                children: [
                  const Expanded(child: _BrandMark()),
                  IconButton(
                    icon: const Icon(Icons.search),
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const GlobalSearchScreen()),
                      );
                    },
                  ),
                ],
              ),
            ),
            Expanded(child: _NavList(index: index, onSelect: onSelect, onAdmin: onAdmin)),
            Divider(height: 1, color: s.border),
            const _UserFooter(),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Rail toujours visible (tablette) — grandes cibles tactiles
// ---------------------------------------------------------------------------
class _Rail extends StatelessWidget {
  final int index;
  final ValueChanged<int> onSelect;
  final VoidCallback? onAdmin;
  const _Rail({required this.index, required this.onSelect, this.onAdmin});

  @override
  Widget build(BuildContext context) {
    final s = AppSurface.of(context);
    final auth = context.watch<AuthProvider>();
    return Container(
      width: 96,
      decoration: BoxDecoration(
        color: s.surface,
        border: Border(right: BorderSide(color: s.border)),
      ),
      child: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: Insets.lg),
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(color: AppColors.brand, borderRadius: BorderRadius.circular(Radii.md)),
              child: const Icon(Icons.inventory_2_rounded, color: Colors.white, size: 22),
            ),
            const SizedBox(height: Insets.md),
            IconButton(
              icon: const Icon(Icons.search),
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const GlobalSearchScreen()),
                );
              },
            ),
            const SizedBox(height: Insets.sm),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: Insets.sm),
                itemCount: _destinations.length,
                itemBuilder: (context, i) => _RailTile(
                  icon: _destinations[i].icon,
                  label: _shortLabel(_destinations[i].label),
                  selected: i == index,
                  onTap: () => onSelect(i),
                ),
              ),
            ),
            if (onAdmin != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: Insets.sm),
                child: _RailTile(
                  icon: Icons.admin_panel_settings_outlined,
                  label: 'Admin',
                  selected: false,
                  onTap: onAdmin!,
                ),
              ),
            const Divider(height: 1),
            const SizedBox(height: Insets.xs),
            const _ThemeToggle(),
            CircleAvatar(
              radius: 16,
              backgroundColor: AppColors.brand.withValues(alpha: 0.15),
              child: Text(
                (auth.user?.name.isNotEmpty ?? false) ? auth.user!.name[0].toUpperCase() : '?',
                style: const TextStyle(color: AppColors.brand, fontWeight: FontWeight.bold, fontSize: 13),
              ),
            ),
            IconButton(
              tooltip: 'Se déconnecter',
              icon: const Icon(Icons.logout, size: 20),
              onPressed: () => auth.logout(),
            ),
            const SizedBox(height: Insets.sm),
          ],
        ),
      ),
    );
  }

  String _shortLabel(String l) => switch (l) {
        'Tableau de bord' => 'Accueil',
        _ => l,
      };
}

class _RailTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _RailTile({required this.icon, required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final s = AppSurface.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Material(
        color: selected ? scheme.primary.withValues(alpha: 0.12) : Colors.transparent,
        borderRadius: BorderRadius.circular(Radii.md),
        child: InkWell(
          borderRadius: BorderRadius.circular(Radii.md),
          onTap: onTap,
          child: Container(
            height: 62, // grande cible tactile
            alignment: Alignment.center,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 24, color: selected ? scheme.primary : s.muted),
                const SizedBox(height: 3),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    color: selected ? scheme.primary : s.muted,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Liste de navigation (barre latérale + tiroir)
// ---------------------------------------------------------------------------
class _NavList extends StatelessWidget {
  final int index;
  final ValueChanged<int> onSelect;
  final VoidCallback? onAdmin;
  const _NavList({required this.index, required this.onSelect, this.onAdmin});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: Insets.md, vertical: Insets.sm),
      children: [
        for (var i = 0; i < _destinations.length; i++)
          _NavTile(
            icon: _destinations[i].icon,
            label: _destinations[i].label,
            selected: i == index,
            onTap: () => onSelect(i),
          ),
        if (onAdmin != null)
          _NavTile(
            icon: Icons.admin_panel_settings_outlined,
            label: 'Administration',
            selected: false,
            onTap: onAdmin!,
          ),
      ],
    );
  }
}

class _NavTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _NavTile({required this.icon, required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final s = AppSurface.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Material(
        color: selected ? scheme.primary.withValues(alpha: 0.12) : Colors.transparent,
        borderRadius: BorderRadius.circular(Radii.sm),
        child: InkWell(
          borderRadius: BorderRadius.circular(Radii.sm),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: Insets.md, vertical: 13),
            child: Row(
              children: [
                Icon(icon, size: 21, color: selected ? scheme.primary : s.muted),
                const SizedBox(width: Insets.md),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                      color: selected ? scheme.primary : s.text,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Marque
// ---------------------------------------------------------------------------
class _BrandMark extends StatelessWidget {
  final bool compact;
  const _BrandMark({this.compact = false});

  @override
  Widget build(BuildContext context) {
    final s = AppSurface.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(color: AppColors.brand, borderRadius: BorderRadius.circular(Radii.sm)),
          child: const Icon(Icons.inventory_2_rounded, color: Colors.white, size: 20),
        ),
        const SizedBox(width: Insets.md),
        Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('RSMS', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, letterSpacing: 0.3)),
            if (!compact) Text('Gestion de stock', style: TextStyle(fontSize: 11, color: s.muted)),
          ],
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Pied utilisateur (barre latérale + tiroir) : thème + profil + déconnexion
// ---------------------------------------------------------------------------
class _UserFooter extends StatelessWidget {
  const _UserFooter();

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final s = AppSurface.of(context);
    return Padding(
      padding: const EdgeInsets.all(Insets.md),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: AppColors.brand.withValues(alpha: 0.15),
            child: Text(
              (auth.user?.name.isNotEmpty ?? false) ? auth.user!.name[0].toUpperCase() : '?',
              style: const TextStyle(color: AppColors.brand, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(width: Insets.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(auth.user?.name ?? '',
                    maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                Text(auth.user?.roleLabel ?? '',
                    maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 11, color: s.muted)),
              ],
            ),
          ),
          const _ThemeToggle(),
          IconButton(
            tooltip: 'Se déconnecter',
            icon: const Icon(Icons.logout, size: 20),
            onPressed: () => auth.logout(),
          ),
        ],
      ),
    );
  }
}

/// Bouton bascule clair/sombre (feature premium, accessible partout).
class _ThemeToggle extends StatelessWidget {
  const _ThemeToggle();

  @override
  Widget build(BuildContext context) {
    final ctrl = context.read<ThemeController>();
    final dark = Theme.of(context).brightness == Brightness.dark;
    return IconButton(
      tooltip: dark ? 'Mode clair' : 'Mode sombre',
      icon: Icon(dark ? Icons.light_mode_rounded : Icons.dark_mode_rounded, size: 20),
      onPressed: () => ctrl.toggle(Theme.of(context).brightness),
    );
  }
}
