import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/location.dart';
import '../models/product.dart';
import '../models/supplier.dart';
import '../services/api_client.dart';
import '../services/connectivity_service.dart';
import '../services/purchase_service.dart';
import '../services/reference_service.dart';
import '../services/offline_service.dart';
import '../theme.dart';
import '../widgets/app_card.dart';
import '../widgets/empty_state.dart';
import '../widgets/responsive.dart';
import '../widgets/skeleton.dart';
import 'product_picker_screen.dart';

class _Line {
  final Product product;
  int qty;
  String? lot;
  DateTime? expiry;
  _Line(this.product, this.qty);
}

class CreatePurchaseScreen extends StatefulWidget {
  const CreatePurchaseScreen({super.key});

  @override
  State<CreatePurchaseScreen> createState() => _CreatePurchaseScreenState();
}

class _CreatePurchaseScreenState extends State<CreatePurchaseScreen> {
  late final PurchaseService _service;
  late final ReferenceService _ref;
  late final OfflineService _offline;
  late final ConnectivityService _connectivity;
  List<Supplier> _suppliers = [];
  Supplier? _supplier;
  Location? _warehouse;
  final List<_Line> _lines = [];
  bool _loading = true;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _service = context.read<PurchaseService>();
    _ref = context.read<ReferenceService>();
    _offline = context.read<OfflineService>();
    _connectivity = context.read<ConnectivityService>();
    _load();
  }

  bool get _isOffline => _connectivity.isOffline;

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      // Offline-aware : retombe sur le cache si l'API est injoignable.
      final suppliers = await _ref.suppliers();
      final wh = await _ref.warehouse();
      if (mounted) {
        setState(() {
          _suppliers = suppliers;
          _warehouse = wh;
        });
      }
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
    if (mounted) setState(() => _lines.add(_Line(p, 1)));
  }

  Future<void> _pickExpiry(_Line line) async {
    final now = DateTime.now();
    final d = await showDatePicker(
      context: context,
      firstDate: now,
      lastDate: DateTime(now.year + 10),
      initialDate: line.expiry ?? DateTime(now.year + 1),
    );
    if (d != null) {
      if (mounted) setState(() => line.expiry = d);
    }
  }

  Future<void> _submit() async {
    if (_supplier == null || _warehouse == null || _lines.isEmpty) return;
    setState(() => _submitting = true);
    
    final items = _lines
        .map((l) => {
              'product_id': l.product.id,
              'quantity': l.qty,
              'unit_price': l.product.purchasePrice,
              if (l.lot != null && l.lot!.isNotEmpty) 'lot_number': l.lot,
              if (l.expiry != null) 'expiry_date': l.expiry!.toIso8601String().substring(0, 10),
            })
        .toList();

    try {
      if (_isOffline) {
        // Mode hors-ligne : on conserve le lieu de réception pour la sync.
        await _offline.addPendingPurchase(
          supplierId: _supplier!.id,
          items: items,
          locationId: _warehouse?.id,
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Achat sauvegardé localement. Synchronisation automatique à la reconnexion.'),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 3),
            ),
          );
          Navigator.of(context).pop(true);
        }
      } else {
        // Mode en ligne: envoyer à l'API
        await _service.create(
          supplierId: _supplier!.id,
          locationId: _warehouse!.id,
          items: items,
        );
        if (mounted) Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        // En cas d'erreur API, essayer de sauvegarder en local
        if (!_isOffline) {
          try {
            await _offline.addPendingPurchase(
              supplierId: _supplier!.id,
              items: items,
              locationId: _warehouse?.id,
            );
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Erreur de connexion. Achat sauvegardé localement.'),
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
    final canSubmit = _supplier != null && _warehouse != null && _lines.isNotEmpty && !_submitting;
    return Scaffold(
      appBar: AppBar(title: const Text('Nouvel achat')),
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
                      Text('Fournisseur & réception', style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: Insets.md),
                      DropdownButtonFormField<Supplier>(
                        initialValue: _supplier,
                        decoration: const InputDecoration(
                            labelText: 'Fournisseur', prefixIcon: Icon(Icons.business)),
                        items: _suppliers.map((x) => DropdownMenuItem(value: x, child: Text(x.name))).toList(),
                        onChanged: (v) => setState(() => _supplier = v),
                      ),
                      const SizedBox(height: Insets.md),
                      Row(
                        children: [
                          const Icon(Icons.warehouse, color: AppColors.brand),
                          const SizedBox(width: Insets.md),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(_warehouse?.name ?? 'Dépôt', style: const TextStyle(fontWeight: FontWeight.w600)),
                                Text('Lieu de réception', style: TextStyle(fontSize: 12, color: s.muted)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: Insets.lg),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Articles', style: Theme.of(context).textTheme.titleMedium),
                    TextButton.icon(
                        onPressed: _addProduct, icon: const Icon(Icons.add), label: const Text('Ajouter')),
                  ],
                ),
                const SizedBox(height: Insets.sm),
                if (_lines.isEmpty)
                  const Padding(
                    padding: EdgeInsets.only(top: Insets.md),
                    child: EmptyState(icon: Icons.inventory_2_outlined, message: 'Aucun article.'),
                  ),
                for (var i = 0; i < _lines.length; i++) ...[
                  if (i > 0) const SizedBox(height: Insets.sm),
                  _lineCard(_lines[i]),
                ],
                const SizedBox(height: Insets.xxl),
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
            label: const Text("Créer l'achat"),
          ),
        ),
      ),
    );
  }

  Widget _lineCard(_Line line) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(line.product.name, style: const TextStyle(fontWeight: FontWeight.w600))),
              IconButton(
                icon: const Icon(Icons.remove_circle_outline),
                onPressed: () => setState(() => line.qty > 1 ? line.qty-- : _lines.remove(line)),
              ),
              Text('${line.qty}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              IconButton(
                icon: const Icon(Icons.add_circle_outline),
                onPressed: () => setState(() => line.qty++),
              ),
            ],
          ),
          Row(
            children: [
              Expanded(
                child: TextField(
                  decoration: const InputDecoration(labelText: 'N° de lot (optionnel)', isDense: true),
                  onChanged: (v) => line.lot = v,
                ),
              ),
              const SizedBox(width: Insets.md),
              OutlinedButton.icon(
                onPressed: () => _pickExpiry(line),
                icon: const Icon(Icons.event, size: 18),
                label: Text(line.expiry == null ? 'Péremption' : line.expiry!.toIso8601String().substring(0, 10)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
