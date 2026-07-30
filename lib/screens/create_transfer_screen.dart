import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/location.dart';
import '../models/product.dart';
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
  _Line(this.product, this.qty);
}

class CreateTransferScreen extends StatefulWidget {
  final bool initialIsReturn;
  const CreateTransferScreen({super.key, this.initialIsReturn = false});

  @override
  State<CreateTransferScreen> createState() => _CreateTransferScreenState();
}

class _CreateTransferScreenState extends State<CreateTransferScreen> {
  late final TransferService _service;
  late final ReferenceService _ref;
  late final OfflineService _offline;
  late final ConnectivityService _connectivity;
  List<Location> _locations = [];
  Location? _from;
  Location? _to;
  bool _isReturn = false;
  final List<_Line> _lines = [];
  bool _loading = true;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _service = context.read<TransferService>();
    _ref = context.read<ReferenceService>();
    _offline = context.read<OfflineService>();
    _connectivity = context.read<ConnectivityService>();
    _isReturn = widget.initialIsReturn;
    _loadLocations();
  }

  bool get _isOffline => _connectivity.isOffline;

  Future<void> _loadLocations() async {
    try {
      // Offline-aware.
      final locs = await _ref.locations();
      if (mounted) setState(() => _locations = locs);
    } catch (e) {
      AppLogger.e('Erreur lors du chargement des lieux', error: e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _addProduct() async {
    final p = await Navigator.of(context)
        .push<Product>(MaterialPageRoute(builder: (_) => const ProductPickerScreen()));
    if (p == null) return;
    setState(() {
      _Line? existing;
      for (final l in _lines) {
        if (l.product.id == p.id) {
          existing = l;
          break;
        }
      }
      if (existing != null) {
        existing.qty++;
      } else {
        _lines.add(_Line(p, 1));
      }
    });
  }

  Future<void> _submit() async {
    if (_from == null || _to == null || _from!.id == _to!.id || _lines.isEmpty) return;
    setState(() => _submitting = true);
    
    final items = _lines.map((l) => {'product_id': l.product.id, 'quantity': l.qty}).toList();

    try {
      if (_isOffline) {
        // Mode hors-ligne: sauvegarder localement
        await _offline.addPendingTransfer(
          fromLocationId: _from!.id,
          toLocationId: _to!.id,
          items: items,
          isReturn: _isReturn,
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
        await _service.create(
          fromLocationId: _from!.id,
          toLocationId: _to!.id,
          isReturn: _isReturn,
          items: items,
        );
        if (mounted) Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        // En cas d'erreur API, essayer de sauvegarder en local
        if (!_isOffline) {
          try {
            await _offline.addPendingTransfer(
              fromLocationId: _from!.id,
              toLocationId: _to!.id,
              items: items,
              isReturn: _isReturn,
            );
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Erreur de connexion. Transfert sauvegardé localement.'),
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
    final canSubmit = _from != null && _to != null && _from!.id != _to!.id && _lines.isNotEmpty && !_submitting;
    return Scaffold(
      appBar: AppBar(title: const Text('Nouveau transfert')),
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
                      Text('Itinéraire', style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: Insets.md),
                      DropdownButtonFormField<Location>(
                        initialValue: _from,
                        decoration: const InputDecoration(
                            labelText: 'De (source)', prefixIcon: Icon(Icons.output)),
                        items: _locations.map((l) => DropdownMenuItem(value: l, child: Text(l.name))).toList(),
                        onChanged: (v) => setState(() => _from = v),
                      ),
                      const SizedBox(height: Insets.md),
                      DropdownButtonFormField<Location>(
                        initialValue: _to,
                        decoration: const InputDecoration(
                            labelText: 'Vers (destination)', prefixIcon: Icon(Icons.input)),
                        items: _locations
                            .where((l) => l.id != _from?.id)
                            .map((l) => DropdownMenuItem(value: l, child: Text(l.name)))
                            .toList(),
                        onChanged: (v) => setState(() => _to = v),
                      ),
                      SwitchListTile(
                        value: _isReturn,
                        onChanged: (v) => setState(() => _isReturn = v),
                        title: const Text('Retour vers le dépôt'),
                        contentPadding: EdgeInsets.zero,
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
                  Padding(
                    padding: const EdgeInsets.only(top: Insets.md),
                    child: EmptyState(
                      icon: Icons.inventory_2_outlined,
                      message: 'Aucun article.',
                      actionLabel: 'Ajouter un article',
                      onAction: _addProduct,
                    ),
                  ),
                ..._buildLines(s),
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
            label: const Text('Créer le transfert'),
          ),
        ),
      ),
    );
  }

  List<Widget> _buildLines(AppSurface s) {
    final widgets = <Widget>[];
    for (var i = 0; i < _lines.length; i++) {
      if (i > 0) widgets.add(const SizedBox(height: Insets.sm));
      widgets.add(_lineCard(s, _lines[i]));
    }
    return widgets;
  }

  Widget _lineCard(AppSurface s, _Line line) {
    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: Insets.md, vertical: Insets.sm),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.brand.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(Radii.sm),
            ),
            child: const Icon(Icons.inventory_2_outlined, color: AppColors.brand, size: 18),
          ),
          const SizedBox(width: Insets.md),
          Expanded(
            child: Text(
              line.product.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.remove_circle_outline),
            color: s.muted,
            onPressed: () => setState(() {
              if (line.qty > 1) {
                line.qty--;
              } else {
                _lines.remove(line);
              }
            }),
          ),
          Text('${line.qty}', style: TextStyle(fontWeight: FontWeight.bold, color: s.text)),
          IconButton(
            icon: const Icon(Icons.add_circle_outline),
            color: AppColors.brand,
            onPressed: () => setState(() => line.qty++),
          ),
        ],
      ),
    );
  }
}
