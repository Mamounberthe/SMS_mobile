import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/purchase.dart';
import '../models/supplier.dart';
import '../services/api_client.dart';
import '../services/supplier_service.dart';
import '../theme.dart';
import '../utils/format.dart';
import '../widgets/app_card.dart';
import '../widgets/confirm_dialog.dart';
import '../widgets/empty_state.dart';
import '../widgets/skeleton.dart';
import '../widgets/status_chip.dart';

/// Gestion des fournisseurs (CRUD + historique achats) — écran poussé.
class SuppliersScreen extends StatefulWidget {
  const SuppliersScreen({super.key});

  @override
  State<SuppliersScreen> createState() => _SuppliersScreenState();
}

class _SuppliersScreenState extends State<SuppliersScreen> {
  late final SupplierService _service;
  List<Supplier> _items = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _service = SupplierService(context.read<ApiClient>());
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final items = await _service.list();
      if (mounted) setState(() => _items = items);
    } catch (e) {
      if (mounted) setState(() => _error = ApiClient.errorMessage(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openForm({Supplier? supplier}) async {
    final name = TextEditingController(text: supplier?.name ?? '');
    final contact = TextEditingController(text: supplier?.contactName ?? '');
    final phone = TextEditingController(text: supplier?.phone ?? '');
    final email = TextEditingController(text: supplier?.email ?? '');
    final address = TextEditingController(text: supplier?.address ?? '');
    String? nameError;
    
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        bool saving = false;
        return StatefulBuilder(
          builder: (ctx, setLocal) => AlertDialog(
            title: Text(supplier == null ? 'Nouveau fournisseur' : 'Modifier le fournisseur'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: name,
                    autofocus: true,
                    decoration: InputDecoration(
                      labelText: 'Nom *',
                      errorText: nameError,
                    ),
                    enabled: !saving,
                  ),
                  const SizedBox(height: Insets.sm),
                  TextField(controller: contact, decoration: const InputDecoration(labelText: 'Contact'), enabled: !saving),
                  const SizedBox(height: Insets.sm),
                  TextField(controller: phone, decoration: const InputDecoration(labelText: 'Téléphone'), keyboardType: TextInputType.phone, enabled: !saving),
                  const SizedBox(height: Insets.sm),
                  TextField(controller: email, decoration: const InputDecoration(labelText: 'Email'), keyboardType: TextInputType.emailAddress, enabled: !saving),
                  const SizedBox(height: Insets.sm),
                  TextField(controller: address, decoration: const InputDecoration(labelText: 'Adresse'), enabled: !saving),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: saving ? null : () => Navigator.pop(ctx, false), child: const Text('Annuler')),
              FilledButton(
                onPressed: saving ? null : () async {
                  if (name.text.trim().isEmpty) {
                    setLocal(() => nameError = 'Le nom est requis');
                    return;
                  }
                  setLocal(() => saving = true);
                  try {
                    final data = {
                      'name': name.text.trim(),
                      'contact_name': contact.text.trim().isEmpty ? null : contact.text.trim(),
                      'phone': phone.text.trim().isEmpty ? null : phone.text.trim(),
                      'email': email.text.trim().isEmpty ? null : email.text.trim(),
                      'address': address.text.trim().isEmpty ? null : address.text.trim(),
                    };
                    if (supplier == null) {
                      await _service.create(data);
                    } else {
                      await _service.update(supplier.id, data);
                    }
                    if (ctx.mounted) Navigator.pop(ctx, true);
                  } catch (e) {
                    setLocal(() => saving = false);
                    if (ctx.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(ApiClient.errorMessage(e)), backgroundColor: Colors.red),
                      );
                    }
                  }
                },
                child: saving
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('Enregistrer'),
              ),
            ],
          ),
        );
      },
    );
    if (ok == true) {
      _load();
    }
  }

  Future<void> _delete(Supplier sup) async {
    final confirmed = await confirmAction(
      context,
      title: 'Supprimer le fournisseur ?',
      message: 'Supprimer le fournisseur « ${sup.name} » ? Cette action est irréversible.',
      confirmLabel: 'Supprimer',
      danger: true,
    );
    if (!confirmed) return;
    
    try {
      await _service.delete(sup.id);
      _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(ApiClient.errorMessage(e)), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _openPurchases(Supplier sup) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => _SupplierPurchasesScreen(service: _service, supplier: sup),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final s = AppSurface.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Fournisseurs')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openForm(),
        icon: const Icon(Icons.add),
        label: const Text('Nouveau'),
      ),
      body: _loading
          ? const SkeletonList()
          : _error != null
              ? EmptyState(icon: Icons.cloud_off, message: _error!, actionLabel: 'Réessayer', onAction: _load)
              : _items.isEmpty
                  ? EmptyState(icon: Icons.business_outlined, message: 'Aucun fournisseur.', actionLabel: 'Nouveau', onAction: () => _openForm())
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView.separated(
                        padding: const EdgeInsets.all(Insets.lg),
                        itemCount: _items.length,
                        separatorBuilder: (_, _) => const SizedBox(height: Insets.sm),
                        itemBuilder: (context, i) {
                          final sup = _items[i];
                          final sub = [sup.contactName, sup.phone].where((e) => e != null && e.isNotEmpty).join(' · ');
                          return AppCard(
                            padding: const EdgeInsets.symmetric(horizontal: Insets.md, vertical: Insets.xs),
                            child: ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: const Icon(Icons.business, color: AppColors.brand),
                              title: Text(sup.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                              subtitle: sub.isEmpty ? null : Text(sub, style: TextStyle(color: s.muted)),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(icon: const Icon(Icons.history), tooltip: 'Historique achats', onPressed: () => _openPurchases(sup)),
                                  IconButton(icon: const Icon(Icons.edit_outlined), onPressed: () => _openForm(supplier: sup)),
                                  IconButton(icon: const Icon(Icons.delete_outline), onPressed: () => _delete(sup)),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
    );
  }
}

/// Historique des achats d'un fournisseur.
class _SupplierPurchasesScreen extends StatefulWidget {
  final SupplierService service;
  final Supplier supplier;
  const _SupplierPurchasesScreen({required this.service, required this.supplier});

  @override
  State<_SupplierPurchasesScreen> createState() => _SupplierPurchasesScreenState();
}

class _SupplierPurchasesScreenState extends State<_SupplierPurchasesScreen> {
  late Future<List<Purchase>> _future;

  @override
  void initState() {
    super.initState();
    _future = widget.service.purchases(widget.supplier.id).then((p) => p.items);
  }

  @override
  Widget build(BuildContext context) {
    final s = AppSurface.of(context);
    return Scaffold(
      appBar: AppBar(title: Text('Achats · ${widget.supplier.name}')),
      body: FutureBuilder<List<Purchase>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) return const SkeletonList();
          if (snap.hasError) return EmptyState(icon: Icons.cloud_off, message: ApiClient.errorMessage(snap.error!));
          final items = snap.data!;
          if (items.isEmpty) return const EmptyState(icon: Icons.shopping_cart_outlined, message: 'Aucun achat pour ce fournisseur.');
          return ListView.separated(
            padding: const EdgeInsets.all(Insets.lg),
            itemCount: items.length,
            separatorBuilder: (_, _) => const SizedBox(height: Insets.sm),
            itemBuilder: (context, i) {
              final p = items[i];
              final info = purchaseStatusInfo(p.status);
              return AppCard(
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(p.reference, style: const TextStyle(fontWeight: FontWeight.w600)),
                          const SizedBox(height: 2),
                          Text(fcfa(p.totalAmount), style: TextStyle(color: s.muted, fontSize: 13)),
                        ],
                      ),
                    ),
                    StatusChip(label: info.label, color: info.color),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
