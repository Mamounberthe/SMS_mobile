import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

import '../models/product.dart';
import '../providers/auth_provider.dart';
import '../services/api_client.dart';
import '../services/offline_service.dart';
import '../services/product_service.dart';
import '../services/export_service.dart';
import '../theme.dart';
import '../widgets/skeleton.dart';
import '../utils/format.dart';
import '../widgets/app_card.dart';
import '../widgets/empty_state.dart';
import '../widgets/page_header.dart';
import 'create_order_screen.dart';
import 'product_detail_screen.dart';
import 'product_form_screen.dart';

/// Produits — corps hébergé dans AppShell (pas de Scaffold propre).
class ProductsScreen extends StatefulWidget {
  const ProductsScreen({super.key});

  @override
  State<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends State<ProductsScreen> {
  late final ProductService _service;
  late final OfflineService _offlineService;
  final _searchCtrl = TextEditingController();
  final _scrollController = ScrollController();

  final List<Product> _products = [];
  bool _loading = false;
  bool _lowStockOnly = false;
  String? _categoryFilter;
  String? _brandFilter;
  String? _error;
  int _page = 1;
  int _lastPage = 1;
  bool _showFilters = false;
  bool _isOffline = false;

  @override
  void initState() {
    super.initState();
    _service = ProductService(context.read<ApiClient>());
    _offlineService = OfflineService();
    _checkConnectivity();
    _load(reset: true);
    
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      _loadMore();
    }
  }

  Future<void> _checkConnectivity() async {
    final connectivityResult = await Connectivity().checkConnectivity();
    setState(() => _isOffline = connectivityResult == ConnectivityResult.none);
    
    // Écouter les changements de connectivité
    Connectivity().onConnectivityChanged.listen((result) async {
      setState(() => _isOffline = result == ConnectivityResult.none);
      if (!_isOffline && _products.isEmpty) {
        _load(reset: true);
      }
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _load({bool reset = false}) async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _error = null;
      if (reset) {
        _page = 1;
        _products.clear();
      }
    });
    
    try {
      if (_isOffline) {
        // Mode hors-ligne : utiliser le cache local
        final hasCache = await _offlineService.hasCachedProducts();
        if (hasCache) {
          final cachedProducts = await _offlineService.getCachedProducts();
          setState(() {
            _products.addAll(cachedProducts);
            _lastPage = 1;
          });
        } else {
          setState(() => _error = 'Aucune donnée disponible hors-ligne. Connectez-vous pour charger les données.');
        }
      } else {
        // Mode en ligne : charger depuis l'API
        final result = await _service.list(
          search: _searchCtrl.text.trim(),
          page: _page,
          lowStockOnly: _lowStockOnly,
          category: _categoryFilter,
          brand: _brandFilter,
        );
        setState(() {
          _products.addAll(result.items);
          _lastPage = result.lastPage;
        });
        
        // Mettre en cache les produits pour usage hors-ligne
        if (reset && result.items.isNotEmpty) {
          await _offlineService.cacheProducts(result.items);
        }
      }
    } catch (e) {
      // En cas d'erreur API, essayer le cache
      if (!_isOffline) {
        try {
          final hasCache = await _offlineService.hasCachedProducts();
          if (hasCache) {
            final cachedProducts = await _offlineService.getCachedProducts();
            setState(() {
              _products.addAll(cachedProducts);
              _lastPage = 1;
              _error = 'Mode hors-ligne : données affichées depuis le cache';
            });
            return;
          }
        } catch (_) {}
      }
      setState(() => _error = ApiClient.errorMessage(e));
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _loadMore() async {
    if (_page >= _lastPage) return;
    _page++;
    await _load();
  }

  void _clearFilters() {
    setState(() {
      _categoryFilter = null;
      _brandFilter = null;
      _lowStockOnly = false;
      _showFilters = false;
    });
    _load(reset: true);
  }

  Future<void> _openForm({Product? product}) async {
    final saved = await Navigator.of(context)
        .push<bool>(MaterialPageRoute(builder: (_) => ProductFormScreen(product: product)));
    if (saved == true) _load(reset: true);
  }

  Future<void> _openDetail(Product p) async {
    final changed = await Navigator.of(context)
        .push<bool>(MaterialPageRoute(builder: (_) => ProductDetailScreen(product: p)));
    if (changed == true) _load(reset: true); // modif/suppression → recharge
  }

  Future<void> _exportProducts() async {
    if (_products.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Aucun produit à exporter')),
      );
      return;
    }
    try {
      final exportService = ExportService();
      await exportService.exportProducts(_products);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur lors de l\'export: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = AppSurface.of(context);
    final hasActiveFilters = _lowStockOnly || _categoryFilter != null || _brandFilter != null;
    final role = context.watch<AuthProvider>().user?.role;
    final canManage = role == 'admin' || role == 'director' || role == 'storekeeper';

    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(Insets.xl, Insets.xl, Insets.xl, Insets.md),
            child: Column(
              children: [
                PageHeader(
                  title: 'Produits',
                  actions: [
                    IconButton.filledTonal(
                      tooltip: 'Exporter en CSV',
                      icon: const Icon(Icons.download),
                      onPressed: _exportProducts,
                    ),
                    IconButton.filledTonal(
                      tooltip: 'Filtres avancés',
                      isSelected: _showFilters || hasActiveFilters,
                      icon: const Icon(Icons.filter_alt_outlined),
                      selectedIcon: const Icon(Icons.filter_alt),
                      onPressed: () => setState(() => _showFilters = !_showFilters),
                    ),
                    if (canManage) ...[
                      const SizedBox(width: Insets.sm),
                      FilledButton.icon(
                        onPressed: () => _openForm(),
                        icon: const Icon(Icons.add),
                        label: const Text('Nouveau'),
                      ),
                    ],
                  ],
                ),
                TextField(
                  controller: _searchCtrl,
                  decoration: InputDecoration(
                    hintText: 'Rechercher (nom, code, référence)…',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchCtrl.text.isEmpty
                        ? null
                        : IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _searchCtrl.clear();
                              _load(reset: true);
                            },
                          ),
                  ),
                  textInputAction: TextInputAction.search,
                  onChanged: (_) => setState(() {}),
                  onSubmitted: (_) => _load(reset: true),
                ),
                
                // Advanced filters panel
                if (_showFilters) ...[
                  const SizedBox(height: Insets.md),
                  AppCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Filtres avancés', style: Theme.of(context).textTheme.titleSmall),
                            if (hasActiveFilters)
                              TextButton(
                                onPressed: _clearFilters,
                                child: const Text('Effacer tout', style: TextStyle(fontSize: 12)),
                              ),
                          ],
                        ),
                        const SizedBox(height: Insets.sm),
                        Row(
                          children: [
                            Expanded(
                              child: FilterChip(
                                label: const Text('Stock faible'),
                                selected: _lowStockOnly,
                                onSelected: (v) {
                                  setState(() => _lowStockOnly = v);
                                  _load(reset: true);
                                },
                                selectedColor: Colors.orange.withValues(alpha: 0.2),
                                checkmarkColor: Colors.orange,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: Insets.sm),
                        TextField(
                          decoration: const InputDecoration(
                            labelText: 'Catégorie',
                            prefixIcon: Icon(Icons.category),
                            isDense: true,
                            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          ),
                          onChanged: (v) {
                            _categoryFilter = v.trim().isEmpty ? null : v.trim();
                            _load(reset: true);
                          },
                        ),
                        const SizedBox(height: Insets.sm),
                        TextField(
                          decoration: const InputDecoration(
                            labelText: 'Marque',
                            prefixIcon: Icon(Icons.business),
                            isDense: true,
                            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          ),
                          onChanged: (v) {
                            _brandFilter = v.trim().isEmpty ? null : v.trim();
                            _load(reset: true);
                          },
                        ),
                      ],
                    ),
                  ),
                ],
                
                // Active filters chips
                if (hasActiveFilters && !_showFilters) ...[
                  const SizedBox(height: Insets.sm),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        if (_lowStockOnly)
                          Padding(
                            padding: const EdgeInsets.only(right: Insets.sm),
                            child: Chip(
                              label: const Text('Stock faible'),
                              deleteIcon: const Icon(Icons.close, size: 16),
                              onDeleted: () {
                                setState(() => _lowStockOnly = false);
                                _load(reset: true);
                              },
                              backgroundColor: Colors.orange.withValues(alpha: 0.2),
                            ),
                          ),
                        if (_categoryFilter != null)
                          Padding(
                            padding: const EdgeInsets.only(right: Insets.sm),
                            child: Chip(
                              label: Text('Catégorie: $_categoryFilter'),
                              deleteIcon: const Icon(Icons.close, size: 16),
                              onDeleted: () {
                                setState(() => _categoryFilter = null);
                                _load(reset: true);
                              },
                            ),
                          ),
                        if (_brandFilter != null)
                          Chip(
                            label: Text('Marque: $_brandFilter'),
                            deleteIcon: const Icon(Icons.close, size: 16),
                            onDeleted: () {
                              setState(() => _brandFilter = null);
                              _load(reset: true);
                            },
                          ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          Expanded(child: _buildBody(s)),
        ],
      ),
    );
  }

  Widget _buildBody(AppSurface s) {
    if (_error != null && _products.isEmpty) {
      return EmptyState(
        icon: Icons.cloud_off,
        message: _error!,
        actionLabel: 'Réessayer',
        onAction: () => _load(reset: true),
      );
    }
    if (_products.isEmpty && _loading) {
      return const SkeletonList();
    }
    if (_products.isEmpty) {
      return const EmptyState(icon: Icons.inventory_2_outlined, message: 'Aucun produit trouvé.');
    }

    return RefreshIndicator(
      onRefresh: () => _load(reset: true),
      child: LayoutBuilder(
        builder: (context, c) {
          final cols = c.maxWidth >= 1100 ? 3 : (c.maxWidth >= 700 ? 2 : 1);
          // Mobile : liste avec actions par glissement (Slidable) conservée.
          if (cols == 1) {
            return ListView.separated(
              controller: _scrollController,
              padding: const EdgeInsets.fromLTRB(Insets.xl, 0, Insets.xl, Insets.xl),
              itemCount: _products.length + 1,
              separatorBuilder: (_, _) => const SizedBox(height: Insets.sm),
              itemBuilder: (context, i) {
                if (i == _products.length) return _footer();
                return _productTile(_products[i], s);
              },
            );
          }
          // Tablette / bureau : grille de cartes.
          const spacing = Insets.md;
          final cardW = (c.maxWidth - 2 * Insets.xl - (cols - 1) * spacing) / cols;
          return ListView(
            padding: const EdgeInsets.fromLTRB(Insets.xl, 0, Insets.xl, Insets.xl),
            children: [
              Wrap(
                spacing: spacing,
                runSpacing: spacing,
                children: [
                  for (final p in _products) SizedBox(width: cardW, child: _productCard(p, s)),
                ],
              ),
              _footer(),
            ],
          );
        },
      ),
    );
  }

  /// Carte produit (grille grand écran).
  Widget _productCard(Product p, AppSurface s) {
    final qty = p.totalQuantity;
    final low = p.isLowStock;
    final accent = low ? Colors.orange : AppColors.brand;
    return AppCard(
      onTap: () => _openDetail(p),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(color: accent.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(Radii.md)),
                child: Icon(Icons.inventory_2_outlined, color: accent),
              ),
              const Spacer(),
              if (qty != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: low ? Colors.orange.withValues(alpha: 0.15) : s.surfaceAlt,
                    borderRadius: BorderRadius.circular(Radii.pill),
                  ),
                  child: Text('$qty ${p.unit}',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: low ? Colors.orange.shade900 : s.text)),
                ),
            ],
          ),
          const SizedBox(height: Insets.md),
          Text(p.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
          const SizedBox(height: 2),
          Text('${p.code}${p.categoryName != null ? ' · ${p.categoryName}' : ''}',
              maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: s.muted, fontSize: 12)),
          const SizedBox(height: Insets.sm),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(fcfa(p.salePrice), style: const TextStyle(fontWeight: FontWeight.w700)),
              IconButton(
                tooltip: 'Commander',
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.add_shopping_cart, size: 20, color: Colors.indigo),
                onPressed: () => _quickOrder(p),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _productTile(Product p, AppSurface s) {
    final qty = p.totalQuantity;
    final low = p.isLowStock;
    return Slidable(
      endActionPane: ActionPane(
        motion: const ScrollMotion(),
        children: [
          SlidableAction(
            onPressed: (_) => Navigator.of(context)
                .push(MaterialPageRoute(builder: (_) => ProductDetailScreen(product: p))),
            backgroundColor: AppColors.brand,
            foregroundColor: Colors.white,
            icon: Icons.visibility,
            label: 'Voir',
          ),
          SlidableAction(
            onPressed: (_) => _quickOrder(p),
            backgroundColor: Colors.indigo,
            foregroundColor: Colors.white,
            icon: Icons.shopping_cart,
            label: 'Commander',
          ),
        ],
      ),
      child: AppCard(
        padding: const EdgeInsets.all(Insets.md),
        onTap: () => _openDetail(p),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: (low ? Colors.orange : AppColors.brand).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(Radii.md),
              ),
              child: Icon(Icons.inventory_2_outlined, color: low ? Colors.orange : AppColors.brand),
            ),
            const SizedBox(width: Insets.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(p.name, maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                  const SizedBox(height: 2),
                  Text('${p.code}${p.categoryName != null ? ' · ${p.categoryName}' : ''}',
                      maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: s.muted, fontSize: 13)),
                ],
              ),
            ),
            const SizedBox(width: Insets.sm),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (qty != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: low ? Colors.orange.withValues(alpha: 0.15) : s.surfaceAlt,
                      borderRadius: BorderRadius.circular(Radii.pill),
                    ),
                    child: Text('$qty ${p.unit}',
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: low ? Colors.orange.shade900 : s.text)),
                  ),
                const SizedBox(height: 4),
                Text(fcfa(p.salePrice), style: TextStyle(fontSize: 12, color: s.muted)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _quickOrder(Product product) async {
    final created = await Navigator.of(context)
        .push<bool>(MaterialPageRoute(builder: (_) => const CreateOrderScreen()));
    if (created == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Commande créée avec succès')),
      );
    }
  }

  Widget _footer() {
    if (_page < _lastPage) {
      return Padding(
        padding: const EdgeInsets.only(top: Insets.md),
        child: Center(
          child: _loading
              ? const CircularProgressIndicator()
              : OutlinedButton.icon(
                  onPressed: _loadMore,
                  icon: const Icon(Icons.expand_more),
                  label: const Text('Charger plus'),
                ),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.only(top: Insets.md),
      child: Center(
        child: Text('${_products.length} produit(s)',
            style: TextStyle(color: AppSurface.of(context).muted, fontSize: 12)),
      ),
    );
  }
}
