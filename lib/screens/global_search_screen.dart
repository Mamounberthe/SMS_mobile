import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/order.dart';
import '../models/product.dart';
import '../models/user.dart';
import '../providers/auth_provider.dart';
import '../services/api_client.dart';
import '../services/order_service.dart';
import '../services/product_service.dart';
import '../services/user_service.dart';
import '../theme.dart';
import '../utils/format.dart';
import '../widgets/app_card.dart';
import '../widgets/empty_state.dart';
import 'product_detail_screen.dart';
import 'order_detail_screen.dart';

/// Résultat de recherche global
enum SearchResultType { product, order, user }

class SearchResult {
  final SearchResultType type;
  final String title;
  final String subtitle;
  final String? id;
  final dynamic data;
  
  SearchResult({
    required this.type,
    required this.title,
    required this.subtitle,
    this.id,
    this.data,
  });
}

/// Écran de recherche global
class GlobalSearchScreen extends StatefulWidget {
  const GlobalSearchScreen({super.key});

  @override
  State<GlobalSearchScreen> createState() => _GlobalSearchScreenState();
}

class _GlobalSearchScreenState extends State<GlobalSearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  final List<SearchResult> _results = [];
  bool _loading = false;
  bool _hasSearched = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    final query = _searchController.text.trim();
    if (query.isEmpty) {
      setState(() {
        _results.clear();
        _hasSearched = false;
        _error = null;
      });
    } else if (query.length >= 2) {
      _performSearch(query);
    }
  }

  Future<void> _performSearch(String query) async {
    setState(() {
      _loading = true;
      _hasSearched = true;
      _error = null;
      _results.clear();
    });

    try {
      final api = context.read<ApiClient>();
      final productService = ProductService(api);
      final orderService = OrderService(api);
      final userService = UserService(api);
      
      final results = <SearchResult>[];
      
      // Recherche produits
      try {
        final products = await productService.list(search: query, perPage: 5);
        for (final p in products.items) {
          results.add(SearchResult(
            type: SearchResultType.product,
            title: p.name,
            subtitle: '${p.code} · ${fcfa(p.salePrice)}',
            id: p.id.toString(),
            data: p,
          ));
        }
      } catch (_) {}
      
      // Recherche commandes (si admin/manager)
      final role = context.read<AuthProvider>().user?.role;
      if (role == 'admin' || role == 'director' || role == 'store_manager') {
        try {
          final ordersRes = await orderService.list(page: 1);
          final orders = ordersRes.items.where((o) =>
            o.reference.toLowerCase().contains(query.toLowerCase())
          ).toList();
          for (final o in orders) {
            results.add(SearchResult(
              type: SearchResultType.order,
              title: o.reference,
              subtitle: '${o.storeName} · ${o.status}',
              id: o.id.toString(),
              data: o,
            ));
          }
        } catch (_) {}
      }
      
      // Recherche utilisateurs (si admin)
      if (role == 'admin' || role == 'director') {
        try {
          final usersRes = await userService.list(page: 1);
          final users = usersRes.items.where((u) =>
            u.name.toLowerCase().contains(query.toLowerCase())
          ).toList();
          for (final u in users) {
            results.add(SearchResult(
              type: SearchResultType.user,
              title: u.name,
              subtitle: '${u.roleLabel} · ${u.email}',
              id: u.id.toString(),
              data: u,
            ));
          }
        } catch (_) {}
      }
      
      if (mounted) {
        setState(() {
          _results.addAll(results);
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = ApiClient.errorMessage(e);
          _loading = false;
        });
      }
    }
  }

  void _navigateToResult(SearchResult result) {
    Navigator.of(context).pop(); // fermer la recherche
    switch (result.type) {
      case SearchResultType.product:
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => ProductDetailScreen(product: result.data as Product)),
        );
        break;
      case SearchResultType.order:
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => OrderDetailScreen(orderId: (result.data as Order).id)),
        );
        break;
      case SearchResultType.user:
        // Pas d'écran détail user, on peut afficher un SnackBar ou naviguer vers admin
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Utilisateur : ${(result.data as User).name}')),
        );
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = AppSurface.of(context);
    
    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _searchController,
          autofocus: true,
          decoration: InputDecoration(
            hintText: 'Rechercher produits, commandes...',
            hintStyle: TextStyle(color: s.muted),
            border: InputBorder.none,
          ),
          style: TextStyle(color: s.text),
        ),
        actions: [
          if (_searchController.text.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.clear),
              onPressed: () {
                _searchController.clear();
                _onSearchChanged();
              },
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? EmptyState(
                  icon: Icons.error_outline,
                  message: _error!,
                  actionLabel: 'Réessayer',
                  onAction: () => _performSearch(_searchController.text),
                )
              : !_hasSearched
                  ? _buildSuggestions(context)
                  : _results.isEmpty
                      ? EmptyState(
                          icon: Icons.search_off,
                          message: 'Aucun résultat pour "${_searchController.text}"',
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.all(Insets.lg),
                          itemCount: _results.length,
                          separatorBuilder: (_, _) => const SizedBox(height: Insets.sm),
                          itemBuilder: (context, i) {
                            final result = _results[i];
                            return _buildResultCard(result, s);
                          },
                        ),
    );
  }

  Widget _buildSuggestions(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(Insets.lg),
      children: [
        Text(
          'Suggestions de recherche',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppSurface.of(context).muted,
          ),
        ),
        const SizedBox(height: Insets.md),
        _buildSuggestionChip('Produits en stock faible'),
        _buildSuggestionChip('Commandes en attente'),
        _buildSuggestionChip('Utilisateurs actifs'),
      ],
    );
  }

  Widget _buildSuggestionChip(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: Insets.sm),
      child: ActionChip(
        label: Text(label),
        onPressed: () {
          _searchController.text = label;
          _performSearch(label);
        },
      ),
    );
  }

  Widget _buildResultCard(SearchResult result, AppSurface s) {
    IconData icon;
    Color color;
    
    switch (result.type) {
      case SearchResultType.product:
        icon = Icons.inventory_2;
        color = AppColors.brand;
        break;
      case SearchResultType.order:
        icon = Icons.receipt_long;
        color = Colors.indigo;
        break;
      case SearchResultType.user:
        icon = Icons.person;
        color = Colors.purple;
        break;
    }
    
    return AppCard(
      child: ListTile(
        contentPadding: EdgeInsets.zero,
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(Radii.sm),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        title: Text(
          result.title,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          result.subtitle,
          style: TextStyle(color: s.muted, fontSize: 13),
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => _navigateToResult(result),
      ),
    );
  }
}
