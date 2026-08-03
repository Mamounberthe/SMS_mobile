import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/location.dart';
import '../models/product.dart';
import '../providers/auth_provider.dart';
import '../services/api_client.dart';
import '../services/connectivity_service.dart';
import '../services/reference_service.dart';
import '../services/transfer_service.dart';
import '../services/offline_service.dart';
import '../theme.dart';
import '../utils/logger.dart';
import '../widgets/app_card.dart';
import '../widgets/empty_state.dart';
import '../widgets/responsive.dart';
import '../widgets/skeleton.dart';
import 'product_picker_screen.dart';

class _Line {
  final Product product;
  int qty;
  int availableStock;
  _Line(this.product, this.qty, this.availableStock);
}

/// Écran dédié au magasinier pour préparer les transferts vers les boutiques
/// Optimisé avec pré-remplissage automatique du lieu source et filtrage des destinations
class StorekeeperTransferScreen extends StatefulWidget {
  const StorekeeperTransferScreen({super.key});

  @override
  State<StorekeeperTransferScreen> createState() => _StorekeeperTransferScreenState();
}

class _StorekeeperTransferScreenState extends State<StorekeeperTransferScreen> {
  late final TransferService _service;
  late final ReferenceService _ref;
  late final OfflineService _offline;
  late final ConnectivityService _connectivity;
  late final AuthProvider _auth;
  
  List<Location> _storeDestinations = [];
  Location? _fromLocation;
  Location? _toLocation;
  final List<_Line> _lines = [];
  bool _loading = true;
  bool _submitting = false;
  bool _autoDispatch = true; // Option pour créer et expédier en une action

  @override
  void initState() {
    super.initState();
    _service = context.read<TransferService>();
    _ref = context.read<ReferenceService>();
    _offline = context.read<OfflineService>();
    _connectivity = context.read<ConnectivityService>();
    _auth = context.read<AuthProvider>();
    
    _loadData();
  }

  Future<void> _loadData() async {
    await _loadStoreDestinations();
    await _loadFromLocation();
  }

  Future<void> _loadFromLocation() async {
    final userLocationId = _auth.user?.locationId;
    if (userLocationId == null) return;
    
    try {
      final allLocations = await _ref.locations();
      final userLocation = allLocations.firstWhere(
        (l) => l.id == userLocationId,
        orElse: () => allLocations.first,
      );
      
      if (mounted) {
        setState(() => _fromLocation = userLocation);
      }
    } catch (e) {
      AppLogger.e('Erreur lors du chargement du lieu source', error: e);
    }
  }

  bool get _isOffline => _connectivity.isOffline;

  /// Charger uniquement les boutiques comme destinations possibles
  Future<void> _loadStoreDestinations() async {
    try {
      final allLocations = await _ref.locations();
      // Filtrer pour ne garder que les boutiques
      final stores = allLocations.where((l) => l.type == 'store').toList();
      
      if (mounted) {
        setState(() {
          _storeDestinations = stores;
          _loading = false;
        });
      }
    } catch (e) {
      AppLogger.e('Erreur lors du chargement des boutiques', error: e);
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _addProduct() async {
    final p = await Navigator.of(context)
        .push<Product>(MaterialPageRoute(
          builder: (_) => ProductPickerScreen(
            sourceLocationId: _fromLocation?.id,
            availableOnly: true,
          ),
        ));
    if (p == null) return;
    
    // Récupérer le stock disponible pour ce produit dans le lieu source
    final availableStock = await _getAvailableStock(p.id, _fromLocation?.id ?? 0);
    
    setState(() {
      _Line? existing;
      for (final l in _lines) {
        if (l.product.id == p.id) {
          existing = l;
          break;
        }
      }
      if (existing != null) {
        // Incrémenter si le stock le permet
        if (existing.qty < existing.availableStock) {
          existing.qty++;
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Stock maximum atteint pour ${p.name}'),
                backgroundColor: Colors.orange,
              ),
            );
          }
        }
      } else {
        if (availableStock > 0) {
          _lines.add(_Line(p, 1, availableStock));
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Stock indisponible pour ${p.name}'),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
      }
    });
  }

  Future<int> _getAvailableStock(int productId, int locationId) async {
    try {
      final api = context.read<ApiClient>();
      final res = await api.dio.get('/stocks', queryParameters: {
        'product_id': productId,
        'location_id': locationId,
      });
      if (res.data['data'] != null && res.data['data'].isNotEmpty) {
        return res.data['data'][0]['available'] ?? 0;
      }
    } catch (e) {
      AppLogger.e('Erreur lors de la récupération du stock', error: e);
    }
    return 0;
  }

  void _updateQuantity(_Line line, int delta) {
    setState(() {
      final newQty = line.qty + delta;
      if (newQty > 0 && newQty <= line.availableStock) {
        line.qty = newQty;
      } else if (newQty > line.availableStock) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Stock maximum (${line.availableStock}) dépassé'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }
    });
  }

  void _removeLine(_Line line) {
    setState(() {
      _lines.remove(line);
    });
  }

  Future<void> _submit() async {
    if (_fromLocation == null || _toLocation == null || _lines.isEmpty) return;
    setState(() => _submitting = true);
    
    final items = _lines.map((l) => {'product_id': l.product.id, 'quantity': l.qty}).toList();

    try {
      if (_isOffline) {
        // Mode hors-ligne: sauvegarder localement
        await _offline.addPendingTransfer(
          fromLocationId: _fromLocation!.id,
          toLocationId: _toLocation!.id,
          items: items,
          isReturn: false,
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Transfert sauvegardé localement. Synchronisation automatique à la reconnexion.'),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 3),
            ),
          );
          Navigator.of(context).pop(true);
        }
      } else {
        // Mode en ligne: envoyer à l'API
        final transfer = await _service.create(
          fromLocationId: _fromLocation!.id,
          toLocationId: _toLocation!.id,
          isReturn: false,
          items: items,
        );
        
        // Expédier automatiquement si l'option est activée
        if (_autoDispatch) {
          await _service.action(transfer.id, 'dispatch');
        }
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(_autoDispatch 
                  ? 'Transfert créé et expédié avec succès' 
                  : 'Transfert créé avec succès'),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 3),
            ),
          );
          Navigator.of(context).pop(true);
        }
      }
    } catch (e) {
      if (mounted) {
        // En cas d'erreur API, essayer de sauvegarder en local
        if (!_isOffline) {
          try {
            await _offline.addPendingTransfer(
              fromLocationId: _fromLocation!.id,
              toLocationId: _toLocation!.id,
              items: items,
              isReturn: false,
            );
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Erreur de connexion. Transfert sauvegardé localement.'),
                  backgroundColor: Colors.orange,
                  duration: Duration(seconds: 3),
                ),
              );
              Navigator.of(context).pop(true);
            }
            return;
          } catch (offlineError) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Erreur: ${ApiClient.errorMessage(e)}'),
                  backgroundColor: Colors.red,
                ),
              );
            }
          }
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Erreur: ${ApiClient.errorMessage(e)}'),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = AppSurface.of(context);
    final canSubmit = _fromLocation != null && _toLocation != null && _lines.isNotEmpty && !_submitting;
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Préparer transfert'),
        actions: [
          if (_lines.isNotEmpty)
            TextButton.icon(
              onPressed: _submitting ? null : _submit,
              icon: const Icon(Icons.send, color: Colors.white),
              label: Text(_autoDispatch ? 'Expédier' : 'Créer', style: const TextStyle(color: Colors.white)),
            ),
        ],
      ),
      body: _loading
          ? const SkeletonList()
          : FormWrap(
              child: ListView(
                padding: formPadding(context),
                children: [
                  // Informations sur le lieu source
                  if (_fromLocation != null)
                    AppCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.store, color: AppColors.brand, size: 20),
                              const SizedBox(width: Insets.sm),
                              Text('Source', style: Theme.of(context).textTheme.titleSmall),
                            ],
                          ),
                          const SizedBox(height: Insets.sm),
                          Text(
                            _fromLocation!.name,
                            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                          ),
                          Text(
                            _fromLocation!.type == 'warehouse' ? 'Dépôt central' : 'Boutique',
                            style: TextStyle(color: s.muted, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                  
                  const SizedBox(height: Insets.lg),
                  
                  // Sélection de la destination
                  AppCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.location_on, color: AppColors.brand, size: 20),
                            const SizedBox(width: Insets.sm),
                            Text('Destination', style: Theme.of(context).textTheme.titleSmall),
                          ],
                        ),
                        const SizedBox(height: Insets.md),
                        DropdownButtonFormField<Location>(
                          initialValue: _toLocation,
                          decoration: const InputDecoration(
                            labelText: 'Sélectionner la boutique',
                            prefixIcon: Icon(Icons.input),
                            hintText: 'Choisir une boutique',
                          ),
                          items: _storeDestinations.map((l) => DropdownMenuItem(
                            value: l,
                            child: Text(l.name),
                          )).toList(),
                          onChanged: (v) => setState(() => _toLocation = v),
                        ),
                        if (_storeDestinations.isEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: Insets.sm),
                            child: Text(
                              'Aucune boutique disponible',
                              style: TextStyle(color: Colors.red.shade700, fontSize: 12),
                            ),
                          ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: Insets.lg),
                  
                  // Option d'expédition automatique
                  AppCard(
                    child: SwitchListTile(
                      value: _autoDispatch,
                      onChanged: (v) => setState(() => _autoDispatch = v),
                      title: const Text('Expédier automatiquement'),
                      subtitle: const Text('Créer et expédier le transfert en une seule action'),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                  
                  const SizedBox(height: Insets.lg),
                  
                  // Liste des produits
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Articles (${_lines.length})', style: Theme.of(context).textTheme.titleMedium),
                      TextButton.icon(
                        onPressed: _addProduct,
                        icon: const Icon(Icons.add),
                        label: const Text('Ajouter'),
                      ),
                    ],
                  ),
                  const SizedBox(height: Insets.sm),
                  
                  if (_lines.isEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: Insets.md),
                      child: EmptyState(
                        icon: Icons.inventory_2_outlined,
                        message: 'Aucun article sélectionné.',
                        actionLabel: 'Ajouter un article',
                        onAction: _addProduct,
                      ),
                    ),
                  
                  for (final line in _lines) ...[
                    const SizedBox(height: Insets.sm),
                    _buildProductCard(line, s),
                  ],
                  
                  const SizedBox(height: Insets.xl),
                  
                  // Résumé
                  if (_lines.isNotEmpty)
                    AppCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Résumé', style: Theme.of(context).textTheme.titleSmall),
                          const SizedBox(height: Insets.md),
                          _buildSummaryRow('Total articles', '${_lines.length}'),
                          _buildSummaryRow('Total quantité', '${_lines.fold<int>(0, (sum, l) => sum + l.qty)}'),
                        ],
                      ),
                    ),
                  
                  const SizedBox(height: Insets.xl),
                  
                  // Bouton de soumission principal
                  if (_lines.isNotEmpty)
                    FilledButton.icon(
                      onPressed: canSubmit ? _submit : null,
                      icon: _submitting 
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                          : Icon(_autoDispatch ? Icons.local_shipping : Icons.check),
                      label: Text(_submitting 
                          ? 'Traitement...' 
                          : (_autoDispatch ? 'Créer et expédier' : 'Créer le transfert')),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(50),
                        backgroundColor: _autoDispatch ? Colors.purple : AppColors.brand,
                      ),
                    ),
                ],
              ),
            ),
    );
  }

  Widget _buildProductCard(_Line line, AppSurface s) {
    final stockPercentage = line.availableStock > 0 
        ? (line.qty / line.availableStock * 100).round() 
        : 0;
    final stockColor = stockPercentage >= 90 
        ? Colors.red 
        : (stockPercentage >= 70 ? Colors.orange : Colors.green);

    return AppCard(
      padding: EdgeInsets.zero,
      child: ListTile(
        title: Text(
          line.product.name,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(line.product.code, style: TextStyle(color: s.muted, fontSize: 12)),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.inventory, size: 14, color: stockColor),
                const SizedBox(width: 4),
                Text(
                  'Disponible: ${line.availableStock}',
                  style: TextStyle(
                    color: stockColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.remove_circle_outline),
              onPressed: line.qty > 1 ? () => _updateQuantity(line, -1) : null,
              color: line.qty > 1 ? Colors.red : Colors.grey,
            ),
            Text(
              '${line.qty}',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            IconButton(
              icon: const Icon(Icons.add_circle_outline),
              onPressed: line.qty < line.availableStock ? () => _updateQuantity(line, 1) : null,
              color: line.qty < line.availableStock ? Colors.green : Colors.grey,
            ),
            const SizedBox(width: Insets.sm),
            IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: () => _removeLine(line),
              color: Colors.red,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Insets.xs),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}