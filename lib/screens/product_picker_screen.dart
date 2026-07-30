import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../models/product.dart';
import '../services/api_client.dart';
import '../services/product_service.dart';
import '../theme.dart';
import '../widgets/skeleton.dart';

enum _SortOption { name, code, stock, price }

/// Écran de sélection d'un produit (recherche avancée). Renvoie le Product choisi
/// via Navigator.pop(product).
class ProductPickerScreen extends StatefulWidget {
  const ProductPickerScreen({super.key});

  @override
  State<ProductPickerScreen> createState() => _ProductPickerScreenState();
}

class _ProductPickerScreenState extends State<ProductPickerScreen> {
  late final ProductService _service;
  final _searchCtrl = TextEditingController();
  List<Product> _products = [];
  List<Product> _recentProducts = [];
  Set<int> _favoriteIds = {};
  Set<int> _selectedIds = {};
  bool _loading = false;
  _SortOption _sortBy = _SortOption.name;
  bool _showRecent = true;
  bool _showFavoritesOnly = false;
  bool _showScanner = false;
  bool _multiSelectMode = false;

  @override
  void initState() {
    super.initState();
    _service = ProductService(context.read<ApiClient>());
    _loadPreferences();
    _search();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    final recentIds = prefs.getStringList('recent_products') ?? [];
    final favoriteIds = prefs.getStringList('favorite_products') ?? [];
    
    if (recentIds.isNotEmpty) {
      try {
        final res = await _service.list(perPage: 50);
        final recent = res.items.where((p) => recentIds.contains(p.id.toString())).toList();
        if (mounted) setState(() => _recentProducts = recent);
      } catch (_) {}
    }
    
    if (mounted) {
      setState(() => _favoriteIds = favoriteIds.map(int.parse).toSet());
    }
  }

  Future<void> _toggleFavorite(Product product) async {
    final prefs = await SharedPreferences.getInstance();
    final favoriteIds = prefs.getStringList('favorite_products') ?? [];
    
    if (_favoriteIds.contains(product.id)) {
      _favoriteIds.remove(product.id);
      favoriteIds.remove(product.id.toString());
    } else {
      _favoriteIds.add(product.id);
      favoriteIds.add(product.id.toString());
    }
    
    await prefs.setStringList('favorite_products', favoriteIds);
    setState(() {});
  }

  Future<void> _addToRecent(Product product) async {
    final prefs = await SharedPreferences.getInstance();
    final recentIds = prefs.getStringList('recent_products') ?? [];
    
    recentIds.remove(product.id.toString());
    recentIds.insert(0, product.id.toString());
    if (recentIds.length > 10) recentIds.removeLast();
    
    await prefs.setStringList('recent_products', recentIds);
  }

  Future<void> _search() async {
    setState(() => _loading = true);
    try {
      final res = await _service.list(search: _searchCtrl.text.trim(), perPage: 50);
      if (mounted) setState(() => _products = _sortProducts(res.items));
    } catch (e) {
      if (mounted) setState(() => _products = []);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur de chargement: ${ApiClient.errorMessage(e)}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _onBarcodeDetected(BarcodeCapture capture) {
    final barcode = capture.barcodes.first;
    if (barcode.rawValue != null) {
      _searchCtrl.text = barcode.rawValue!;
      _search();
      setState(() => _showScanner = false);
    }
  }

  void _toggleSelection(int productId) {
    setState(() {
      if (_selectedIds.contains(productId)) {
        _selectedIds.remove(productId);
      } else {
        _selectedIds.add(productId);
      }
    });
  }

  void _toggleMultiSelectMode() {
    setState(() {
      _multiSelectMode = !_multiSelectMode;
      _selectedIds.clear();
    });
  }

  void _confirmSelection() {
    final selectedProducts = _products.where((p) => _selectedIds.contains(p.id)).toList();
    if (selectedProducts.isEmpty) return;
    
    // Ajouter aux récents
    for (final p in selectedProducts) {
      _addToRecent(p);
    }
    
    Navigator.of(context).pop(selectedProducts);
  }

  List<Product> _sortProducts(List<Product> products) {
    switch (_sortBy) {
      case _SortOption.name:
        products.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
        break;
      case _SortOption.code:
        products.sort((a, b) => a.code.compareTo(b.code));
        break;
      case _SortOption.stock:
        products.sort((a, b) => (b.totalQuantity ?? 0).compareTo(a.totalQuantity ?? 0));
        break;
      case _SortOption.price:
        products.sort((a, b) => a.salePrice.compareTo(b.salePrice));
        break;
    }
    return products;
  }

  void _changeSort(_SortOption option) {
    setState(() {
      _sortBy = option;
      _products = _sortProducts(_products);
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = AppSurface.of(context);
    final displayProducts = _showFavoritesOnly 
        ? _products.where((p) => _favoriteIds.contains(p.id)).toList()
        : _products;
    
    final showRecentSection = _showRecent && _recentProducts.isNotEmpty && _searchCtrl.text.isEmpty;

    if (_showScanner) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Scanner code-barres'),
          actions: [
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: () => setState(() => _showScanner = false),
            ),
          ],
        ),
        body: MobileScanner(
          onDetect: _onBarcodeDetected,
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_multiSelectMode 
            ? '${_selectedIds.length} sélectionné(s)' 
            : 'Choisir un produit'),
        actions: [
          if (_multiSelectMode && _selectedIds.isNotEmpty)
            TextButton.icon(
              onPressed: _confirmSelection,
              icon: const Icon(Icons.check, color: Colors.white),
              label: const Text('Valider', style: TextStyle(color: Colors.white)),
            ),
          IconButton(
            icon: Icon(_multiSelectMode ? Icons.close : Icons.checklist),
            onPressed: _toggleMultiSelectMode,
            tooltip: _multiSelectMode ? 'Annuler sélection' : 'Sélection multiple',
          ),
          IconButton(
            icon: const Icon(Icons.qr_code_scanner),
            onPressed: () => setState(() => _showScanner = true),
            tooltip: 'Scanner code-barres',
          ),
          PopupMenuButton<_SortOption>(
            icon: const Icon(Icons.sort),
            onSelected: _changeSort,
            itemBuilder: (context) => [
              const PopupMenuItem(value: _SortOption.name, child: Text('Par nom')),
              const PopupMenuItem(value: _SortOption.code, child: Text('Par code')),
              const PopupMenuItem(value: _SortOption.stock, child: Text('Par stock')),
              const PopupMenuItem(value: _SortOption.price, child: Text('Par prix')),
            ],
          ),
          IconButton(
            icon: Icon(_showFavoritesOnly ? Icons.star : Icons.star_border),
            onPressed: () => setState(() => _showFavoritesOnly = !_showFavoritesOnly),
            tooltip: 'Favoris seulement',
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(Insets.md),
            child: TextField(
              controller: _searchCtrl,
              autofocus: true,
              decoration: InputDecoration(
                hintText: 'Rechercher (nom, code, référence)…',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchCtrl.text.isEmpty
                    ? IconButton(
                        icon: const Icon(Icons.qr_code_scanner),
                        onPressed: () => setState(() => _showScanner = true),
                        tooltip: 'Scanner',
                      )
                    : IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchCtrl.clear();
                          _search();
                        },
                      ),
              ),
              textInputAction: TextInputAction.search,
              onChanged: (_) => setState(() {}),
              onSubmitted: (_) => _search(),
            ),
          ),
          Expanded(
            child: ListView(
              children: [
                if (displayProducts.isEmpty && _recentProducts.isEmpty && _loading)
                  const SkeletonList(count: 8, padding: EdgeInsets.all(Insets.md)),
                if (showRecentSection) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: Insets.md, vertical: Insets.sm),
                    child: Row(
                      children: [
                        Text('Récents', style: TextStyle(fontWeight: FontWeight.w600, color: s.text)),
                        const Spacer(),
                        TextButton(
                          onPressed: () => setState(() => _showRecent = false),
                          child: const Text('Masquer', style: TextStyle(fontSize: 12)),
                        ),
                      ],
                    ),
                  ),
                  ..._recentProducts.map((p) => _productTile(p, s, isRecent: true)),
                  const Divider(height: 32),
                ],
                if (displayProducts.isEmpty && !_loading)
                  Padding(
                    padding: const EdgeInsets.all(Insets.xl),
                    child: Text(
                      _showFavoritesOnly ? 'Aucun favori.' : 'Aucun produit trouvé.',
                      style: TextStyle(color: s.muted),
                    ),
                  ),
                ...displayProducts.map((p) => _productTile(p, s)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _productTile(Product p, AppSurface s, {bool isRecent = false}) {
    final isFavorite = _favoriteIds.contains(p.id);
    final isSelected = _selectedIds.contains(p.id);
    
    return ListTile(
      leading: _multiSelectMode
          ? Checkbox(
              value: isSelected,
              onChanged: (_) => _toggleSelection(p.id),
              activeColor: AppColors.brand,
            )
          : Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.brand.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(Radii.md),
              ),
              child: const Icon(Icons.inventory_2_outlined, color: AppColors.brand, size: 22),
            ),
      title: Text(
        p.name,
        style: TextStyle(
          fontWeight: FontWeight.w600, 
          fontSize: 15,
          color: _multiSelectMode && isSelected ? AppColors.brand : null,
        ),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(p.code, style: TextStyle(color: s.muted, fontSize: 13)),
          if (p.totalQuantity != null)
            Text('Stock: ${p.totalQuantity} ${p.unit}', style: TextStyle(color: s.muted, fontSize: 12)),
        ],
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!_multiSelectMode && !isRecent)
            IconButton(
              icon: Icon(isFavorite ? Icons.star : Icons.star_border),
              color: isFavorite ? Colors.amber : s.muted,
              onPressed: () => _toggleFavorite(p),
              tooltip: 'Favori',
            ),
          if (!_multiSelectMode)
            const Icon(Icons.add_circle_outline, color: AppColors.brand),
        ],
      ),
      onTap: () {
        if (_multiSelectMode) {
          _toggleSelection(p.id);
        } else {
          _addToRecent(p);
          Navigator.of(context).pop(p);
        }
      },
      selected: _multiSelectMode && isSelected,
      selectedTileColor: AppColors.brand.withValues(alpha: 0.08),
    );
  }
}
