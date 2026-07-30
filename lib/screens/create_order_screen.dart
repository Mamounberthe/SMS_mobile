import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/location.dart';
import '../models/order_template.dart';
import '../models/product.dart';
import '../providers/auth_provider.dart';
import '../services/api_client.dart';
import '../services/connectivity_service.dart';
import '../services/offline_service.dart';
import '../services/order_service.dart';
import '../services/product_service.dart';
import '../services/reference_service.dart';
import '../services/template_service.dart';
import '../theme.dart';
import '../utils/format.dart';
import '../utils/page_transitions.dart';
import '../utils/validation.dart';
import '../widgets/app_card.dart';
import '../widgets/empty_state.dart';
import '../widgets/responsive.dart';
import '../widgets/skeleton.dart';
import 'product_picker_screen.dart';

/// Ligne en cours de saisie (produit + quantité).
class _Line {
  final Product product;
  int qty;
  _Line(this.product, this.qty);
}

class CreateOrderScreen extends StatefulWidget {
  const CreateOrderScreen({super.key});

  @override
  State<CreateOrderScreen> createState() => _CreateOrderScreenState();
}

class _CreateOrderScreenState extends State<CreateOrderScreen> {
  late final OrderService _service;
  late final ProductService _productService;
  late final TemplateService _templateService;
  late final OfflineService _offline;
  late final ReferenceService _ref;
  List<Location> _stores = [];
  Location? _store;
  final List<_Line> _lines = [];
  bool _loadingStores = true;
  bool _submitting = false;
  bool _isGlobal = false;
  List<Product> _suggestedProducts = [];
  bool _showSuggestions = true;
  List<OrderTemplate> _templates = [];
  bool _loadingTemplates = false;

  @override
  void initState() {
    super.initState();
    _service = context.read<OrderService>();
    _productService = ProductService(context.read<ApiClient>());
    _templateService = TemplateService(context.read<ApiClient>());
    _offline = context.read<OfflineService>();
    _ref = context.read<ReferenceService>();
    final user = context.read<AuthProvider>().user;
    _isGlobal = user?.role == 'admin' || user?.role == 'director';
    _loadStores(user?.locationId);
    _loadSuggestedProducts();
    _loadTemplates();
  }

  Future<void> _loadStores(int? userLocationId) async {
    setState(() => _loadingStores = true);
    try {
      // Offline-aware : retombe sur le cache si l'API est injoignable.
      final stores = await _ref.locations(type: 'store');
      if (mounted) {
        setState(() {
          _stores = stores;
          if (!_isGlobal && userLocationId != null) {
            for (final s in stores) {
              if (s.id == userLocationId) {
                _store = s;
                break;
              }
            }
          }
        });
      }
    } catch (_) {
      // on laisse la liste vide ; l'utilisateur verra le message
    } finally {
      if (mounted) setState(() => _loadingStores = false);
    }
  }

  Future<void> _loadSuggestedProducts() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final recentIds = prefs.getStringList('recent_products') ?? [];
      
      if (recentIds.isNotEmpty) {
        final res = await _productService.list(perPage: 50, lowStockOnly: true);
        final suggested = res.items
            .where((p) => recentIds.contains(p.id.toString()) && !_lines.any((l) => l.product.id == p.id))
            .take(5)
            .toList();
        
        if (mounted) setState(() => _suggestedProducts = suggested);
      }
    } catch (_) {}
  }

  Future<void> _addSuggestedProduct(Product product) async {
    setState(() {
      _Line? existing;
      for (final l in _lines) {
        if (l.product.id == product.id) {
          existing = l;
          break;
        }
      }
      if (existing != null) {
        existing.qty++;
      } else {
        _lines.add(_Line(product, product.minStock > 0 ? product.minStock : 1));
      }
      _suggestedProducts.remove(product);
    });
  }

  Future<void> _loadTemplates() async {
    setState(() => _loadingTemplates = true);
    try {
      final templates = await _templateService.list();
      if (mounted) setState(() => _templates = templates);
    } catch (_) {
      // Silencieux - les templates sont optionnels
    } finally {
      if (mounted) setState(() => _loadingTemplates = false);
    }
  }

  Future<void> _applyTemplate(OrderTemplate template) async {
    // Charger les produits complets pour chaque item du template
    try {
      final res = await _productService.list(perPage: 100);
      final productMap = {for (var p in res.items) p.id: p};
      
      if (mounted) {
        setState(() {
          for (final item in template.items) {
            final product = productMap[item.productId];
            if (product != null) {
              _Line? existing;
              for (final l in _lines) {
                if (l.product.id == product.id) {
                  existing = l;
                  break;
                }
              }
              if (existing != null) {
                existing.qty += item.quantity;
              } else {
                _lines.add(_Line(product, item.quantity));
              }
            }
          }
        });
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Template "${template.name}" appliqué')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur lors de l\'application du template'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _saveAsTemplate() async {
    if (_lines.isEmpty) return;
    
    final nameField = ValidatedField<String>(
      value: '',
      validator: Validators.combine<String>([
        Validators.required(),
        Validators.minLength(3),
        Validators.maxLength(50),
      ]),
    );
    
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sauvegarder comme template'),
        content: StatefulBuilder(
          builder: (context, setState) => ValidatedTextField(
            field: nameField,
            label: 'Nom du template',
            hint: 'Ex: Commande mensuelle standard',
            maxLength: 50,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: nameField.isValid ? () => Navigator.pop(context, nameField.value) : null,
            child: const Text('Sauvegarder'),
          ),
        ],
      ),
    );
    
    if (name == null || name.isEmpty) return;
    
    try {
      final items = _lines.map((l) => {
        'product_id': l.product.id,
        'product_name': l.product.name,
        'quantity': l.qty,
      }).toList();
      
      await _templateService.create(name: name, items: items);
      await _loadTemplates();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Template sauvegardé avec succès')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur lors de la sauvegarde'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _showTemplateDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Choisir un template'),
        content: SizedBox(
          width: double.maxFinite,
          child: _loadingTemplates
              ? const Center(child: CircularProgressIndicator())
              : ListView.builder(
                  shrinkWrap: true,
                  itemCount: _templates.length,
                  itemBuilder: (context, i) {
                    final template = _templates[i];
                    return ListTile(
                      title: Text(template.name),
                      subtitle: Text('${template.items.length} articles'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () {
                        Navigator.pop(context);
                        _applyTemplate(template);
                      },
                    );
                  },
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
        ],
      ),
    );
  }

  Future<void> _addProduct() async {
    final result = await Navigator.of(context)
        .push<dynamic>(SlidePageRoute(child: const ProductPickerScreen()));
    
    if (result == null) return;
    
    if (!mounted) return;
    
    setState(() {
      if (result is Product) {
        // Sélection simple (ancien comportement)
        _Line? existing;
        for (final l in _lines) {
          if (l.product.id == result.id) {
            existing = l;
            break;
          }
        }
        if (existing != null) {
          existing.qty++;
        } else {
          _lines.add(_Line(result, 1));
        }
      } else if (result is List<Product>) {
        // Sélection multiple (nouveau comportement)
        for (final product in result) {
          _Line? existing;
          for (final l in _lines) {
            if (l.product.id == product.id) {
              existing = l;
              break;
            }
          }
          if (existing != null) {
            existing.qty++;
          } else {
            _lines.add(_Line(product, 1));
          }
        }
      }
    });
  }

  Future<void> _submit() async {
    if (_store == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez sélectionner une boutique'), backgroundColor: Colors.red),
      );
      return;
    }

    if (_lines.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez ajouter au moins un produit'), backgroundColor: Colors.red),
      );
      return;
    }

    setState(() => _submitting = true);
    final items = _lines.map((l) => {'product_id': l.product.id, 'quantity': l.qty}).toList();
    final isOffline = context.read<ConnectivityService>().isOffline;

    try {
      if (isOffline) {
        // Mode hors-ligne : mettre en file d'attente (sera synchronisé au retour réseau).
        await _offline.addPendingOrder(storeId: _store!.id, items: items);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Commande sauvegardée localement. Synchronisation automatique à la reconnexion.'),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 3),
            ),
          );
          Navigator.of(context).pop(true);
        }
      } else {
        await _service.create(storeId: _store!.id, items: items);
        if (mounted) Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        // En cas d'erreur API alors qu'on croyait être en ligne, on bascule
        // en file d'attente pour ne pas perdre la saisie.
        if (!isOffline) {
          try {
            await _offline.addPendingOrder(storeId: _store!.id, items: items);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Erreur de connexion. Commande sauvegardée localement.'),
                backgroundColor: Colors.orange,
                duration: Duration(seconds: 3),
              ),
            );
            Navigator.of(context).pop(true);
            return;
          } catch (_) {
            // Échec SQLite : on affiche l'erreur d'origine.
          }
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(ApiClient.errorMessage(e)), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final canSubmit = _store != null && _lines.isNotEmpty && !_submitting;
    final s = AppSurface.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Nouvelle commande')),
      body: _loadingStores
          ? const SkeletonList()
          : FormWrap(
              child: ListView(
                padding: formPadding(context),
                children: [
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Boutique destinataire', style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: Insets.md),
                      if (_isGlobal)
                        DropdownButtonFormField<Location>(
                          initialValue: _store,
                          decoration: const InputDecoration(
                              labelText: 'Boutique', prefixIcon: Icon(Icons.store)),
                          items: _stores
                              .map((s) => DropdownMenuItem(value: s, child: Text(s.name)))
                              .toList(),
                          onChanged: (v) => setState(() => _store = v),
                        )
                      else
                        Row(
                          children: [
                            const Icon(Icons.store, color: AppColors.brand),
                            const SizedBox(width: Insets.md),
                            Text(_store?.name ?? 'Votre boutique',
                                style: const TextStyle(fontWeight: FontWeight.w600)),
                          ],
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: Insets.lg),
                
                // Suggestions de produits
                if (_showSuggestions && _suggestedProducts.isNotEmpty) ...[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Suggestions', style: Theme.of(context).textTheme.titleMedium),
                      TextButton(
                        onPressed: () => setState(() => _showSuggestions = false),
                        child: const Text('Masquer', style: TextStyle(fontSize: 12)),
                      ),
                    ],
                  ),
                  const SizedBox(height: Insets.sm),
                  Wrap(
                    spacing: Insets.sm,
                    runSpacing: Insets.sm,
                    children: _suggestedProducts.map((p) => 
                      Chip(
                        avatar: Container(
                          width: 20,
                          height: 20,
                          decoration: BoxDecoration(
                            color: Colors.orange.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(Icons.warning_amber_rounded, size: 12, color: Colors.orange.shade800),
                        ),
                        label: Text(p.name, style: const TextStyle(fontSize: 12)),
                        deleteIcon: const Icon(Icons.add, size: 16),
                        onDeleted: () => _addSuggestedProduct(p),
                      ),
                    ).toList(),
                  ),
                  const SizedBox(height: Insets.lg),
                ],
                
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Articles', style: Theme.of(context).textTheme.titleMedium),
                    Row(
                      children: [
                        if (_templates.isNotEmpty)
                          TextButton.icon(
                            onPressed: () => _showTemplateDialog(),
                            icon: const Icon(Icons.bookmark_border),
                            label: const Text('Templates'),
                          ),
                        TextButton.icon(
                            onPressed: _addProduct, icon: const Icon(Icons.add), label: const Text('Ajouter')),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: Insets.sm),
                if (_lines.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: Insets.md),
                    child: EmptyState(
                      icon: Icons.inventory_2_outlined, 
                      message: 'Aucun article. Appuie sur « Ajouter ».',
                      actionLabel: _suggestedProducts.isNotEmpty ? 'Voir les suggestions' : null,
                      onAction: _suggestedProducts.isNotEmpty 
                          ? () => setState(() => _showSuggestions = true) 
                          : null,
                    ),
                  ),
                for (var i = 0; i < _lines.length; i++) ...[
                  if (i > 0) const SizedBox(height: Insets.sm),
                  _lineCard(_lines[i], s),
                ],
                
                // Résumé de la commande
                if (_lines.isNotEmpty) ...[
                  const SizedBox(height: Insets.lg),
                  AppCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Résumé', style: Theme.of(context).textTheme.titleMedium),
                        const SizedBox(height: Insets.md),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Total articles', style: TextStyle(color: s.muted)),
                            Text('${_lines.length}', style: const TextStyle(fontWeight: FontWeight.bold)),
                          ],
                        ),
                        const SizedBox(height: Insets.sm),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Quantité totale', style: TextStyle(color: s.muted)),
                            Text('${_lines.fold<int>(0, (sum, l) => sum + l.qty)}', 
                                 style: const TextStyle(fontWeight: FontWeight.bold)),
                          ],
                        ),
                        const SizedBox(height: Insets.sm),
                        TextButton.icon(
                          onPressed: _saveAsTemplate,
                          icon: const Icon(Icons.bookmark_add, size: 18),
                          label: const Text('Sauvegarder comme template'),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: Insets.xxl),
              ],
            ),
          ),
        ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(Insets.md),
          child: FilledButton.icon(
            onPressed: canSubmit ? _submit : null,
            style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
            icon: _submitting
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.check),
            label: const Text('Créer la commande'),
          ),
        ),
      ),
    );
  }

  Widget _lineCard(_Line line, AppSurface s) {
    final lowStock = line.product.totalQuantity != null && 
                     line.product.totalQuantity! <= line.product.minStock;
    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: Insets.md, vertical: Insets.sm),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: (lowStock ? Colors.orange : AppColors.brand).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(Radii.sm),
            ),
            child: Icon(Icons.inventory_2_outlined, 
                       color: lowStock ? Colors.orange : AppColors.brand, 
                       size: 18),
          ),
          const SizedBox(width: Insets.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(line.product.name, 
                     maxLines: 1, 
                     overflow: TextOverflow.ellipsis,
                     style: const TextStyle(fontWeight: FontWeight.w600)),
                if (line.product.minStock > 0)
                  Text('Min: ${line.product.minStock} ${line.product.unit}', 
                       style: TextStyle(color: s.muted, fontSize: 11)),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.remove_circle_outline),
            onPressed: () => setState(() {
              if (line.qty > 1) {
                line.qty--;
              } else {
                _lines.remove(line);
              }
            }),
          ),
          Text('${line.qty}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          IconButton(
            icon: const Icon(Icons.add_circle_outline),
            onPressed: () => setState(() => line.qty++),
          ),
        ],
      ),
    );
  }
}
