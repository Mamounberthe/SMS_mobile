import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/location.dart';
import '../models/product.dart';
import '../services/api_client.dart';
import '../services/connectivity_service.dart';
import '../services/inventory_service.dart';
import '../services/reference_service.dart';
import '../services/offline_service.dart';
import '../theme.dart';
import '../widgets/app_card.dart';
import '../widgets/responsive.dart';
import '../widgets/skeleton.dart';
import 'product_picker_screen.dart';

class CreateInventoryScreen extends StatefulWidget {
  const CreateInventoryScreen({super.key});

  @override
  State<CreateInventoryScreen> createState() => _CreateInventoryScreenState();
}

class _CreateInventoryScreenState extends State<CreateInventoryScreen> {
  late final InventoryService _service;
  late final ReferenceService _ref;
  late final OfflineService _offline;
  late final ConnectivityService _connectivity;
  List<Location> _locations = [];
  Location? _location;
  String _type = 'partial';
  final List<Product> _products = [];
  bool _loading = true;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _service = context.read<InventoryService>();
    _ref = context.read<ReferenceService>();
    _offline = context.read<OfflineService>();
    _connectivity = context.read<ConnectivityService>();
    _load();
  }

  bool get _isOffline => _connectivity.isOffline;

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      // Offline-aware.
      final locs = await _ref.locations();
      if (mounted) setState(() => _locations = locs);
    } catch (_) {
      // liste vide en cas d'erreur
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _addProduct() async {
    final p = await Navigator.of(context)
        .push<Product>(MaterialPageRoute(builder: (_) => const ProductPickerScreen()));
    if (p == null) return;
    if (_products.any((x) => x.id == p.id)) return;
    if (mounted) setState(() => _products.add(p));
  }

  Future<void> _submit() async {
    if (_location == null) return;
    if (_type == 'partial' && _products.isEmpty) return;
    setState(() => _submitting = true);
    
    final items = _products.map((p) => {'product_id': p.id}).toList();

    try {
      if (_isOffline) {
        // Mode hors-ligne: sauvegarder localement
        await _offline.addPendingInventory(
          locationId: _location!.id,
          type: _type,
          items: items,
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Inventaire sauvegardé localement. Synchronisation automatique à la reconnexion.'),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 3),
            ),
          );
          Navigator.of(context).pop(true);
        }
      } else {
        // Mode en ligne: envoyer à l'API
        await _service.create(
          locationId: _location!.id,
          type: _type,
          productIds: _products.map((p) => p.id).toList(),
        );
        if (mounted) Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        // En cas d'erreur API, essayer de sauvegarder en local
        if (!_isOffline) {
          try {
            await _offline.addPendingInventory(
              locationId: _location!.id,
              type: _type,
              items: items,
            );
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Erreur de connexion. Inventaire sauvegardé localement.'),
                backgroundColor: Colors.orange,
                duration: Duration(seconds: 3),
              ),
            );
            Navigator.of(context).pop(true);
            return;
          } catch (offlineError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Erreur: ${ApiClient.errorMessage(e)}'),
                backgroundColor: Colors.red,
              ),
            );
          }
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Erreur: ${ApiClient.errorMessage(e)}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = AppSurface.of(context);
    final canSubmit = _location != null && (_type == 'full' || _products.isNotEmpty) && !_submitting;
    return Scaffold(
      appBar: AppBar(title: const Text('Nouvel inventaire')),
      body: _loading
          ? const SkeletonList()
          : FormWrap(
              child: ListView(
                padding: formPadding(context),
                children: [
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Paramètres', style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: Insets.md),
                      DropdownButtonFormField<Location>(
                        initialValue: _location,
                        decoration: const InputDecoration(labelText: 'Lieu', prefixIcon: Icon(Icons.place)),
                        items: _locations.map((l) => DropdownMenuItem(value: l, child: Text(l.name))).toList(),
                        onChanged: (v) => setState(() => _location = v),
                      ),
                      const SizedBox(height: Insets.md),
                      SizedBox(
                        width: double.infinity,
                        child: SegmentedButton<String>(
                          segments: const [
                            ButtonSegment(value: 'partial', label: Text('Partiel'), icon: Icon(Icons.checklist)),
                            ButtonSegment(value: 'full', label: Text('Complet'), icon: Icon(Icons.all_inbox)),
                          ],
                          selected: {_type},
                          onSelectionChanged: (sel) => setState(() => _type = sel.first),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: Insets.lg),
                if (_type == 'partial') ...[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Produits à compter', style: Theme.of(context).textTheme.titleMedium),
                      TextButton.icon(
                          onPressed: _addProduct, icon: const Icon(Icons.add), label: const Text('Ajouter')),
                    ],
                  ),
                  const SizedBox(height: Insets.sm),
                  if (_products.isEmpty)
                    Text('Choisis au moins un produit.', style: TextStyle(color: s.muted)),
                  Wrap(
                    spacing: Insets.sm,
                    runSpacing: Insets.sm,
                    children: _products
                        .map((p) => Chip(
                              label: Text(p.name),
                              onDeleted: () => setState(() => _products.remove(p)),
                            ))
                        .toList(),
                  ),
                ] else
                  AppCard(
                    child: Row(
                      children: [
                        const Icon(Icons.all_inbox, color: AppColors.brand),
                        const SizedBox(width: Insets.md),
                        Expanded(child: Text('Tous les produits actifs du lieu seront inclus.', style: TextStyle(color: s.muted))),
                      ],
                    ),
                  ),
              ],
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
            label: const Text("Démarrer l'inventaire"),
          ),
        ),
      ),
    );
  }
}
