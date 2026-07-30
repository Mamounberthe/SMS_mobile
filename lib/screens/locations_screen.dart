import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/location.dart';
import '../services/api_client.dart';
import '../services/location_service.dart';
import '../theme.dart';
import '../widgets/app_card.dart';
import '../widgets/confirm_dialog.dart';
import '../widgets/empty_state.dart';
import '../widgets/skeleton.dart';

/// Gestion des lieux (dépôt & boutiques) — réservé admin.
class LocationsScreen extends StatefulWidget {
  const LocationsScreen({super.key});

  @override
  State<LocationsScreen> createState() => _LocationsScreenState();
}

class _LocationsScreenState extends State<LocationsScreen> {
  late final LocationService _service;
  List<Location> _items = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _service = LocationService(context.read<ApiClient>());
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

  Future<void> _openForm({Location? location}) async {
    final name = TextEditingController(text: location?.name ?? '');
    final code = TextEditingController(text: location?.code ?? '');
    final address = TextEditingController(text: location?.address ?? '');
    final phone = TextEditingController(text: location?.phone ?? '');
    String type = location?.type ?? 'store';
    bool active = location?.isActive ?? true;
    String? nameError;
    String? codeError;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        bool saving = false;
        return StatefulBuilder(
          builder: (ctx, setLocal) => AlertDialog(
            title: Text(location == null ? 'Nouveau lieu' : 'Modifier le lieu'),
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
                  TextField(
                    controller: code,
                    decoration: InputDecoration(
                      labelText: 'Code *',
                      errorText: codeError,
                    ),
                    enabled: !saving,
                  ),
                  const SizedBox(height: Insets.sm),
                  DropdownButtonFormField<String>(
                    initialValue: type,
                    decoration: const InputDecoration(labelText: 'Type *'),
                    items: const [
                      DropdownMenuItem(value: 'store', child: Text('Boutique')),
                      DropdownMenuItem(value: 'warehouse', child: Text('Dépôt central')),
                    ],
                    onChanged: saving ? null : (v) => setLocal(() => type = v ?? type),
                  ),
                  const SizedBox(height: Insets.sm),
                  TextField(controller: address, decoration: const InputDecoration(labelText: 'Adresse'), enabled: !saving),
                  const SizedBox(height: Insets.sm),
                  TextField(controller: phone, decoration: const InputDecoration(labelText: 'Téléphone'), keyboardType: TextInputType.phone, enabled: !saving),
                  SwitchListTile(
                    value: active,
                    onChanged: saving ? null : (v) => setLocal(() => active = v),
                    title: const Text('Lieu actif'),
                    contentPadding: EdgeInsets.zero,
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: saving ? null : () => Navigator.pop(ctx, false), child: const Text('Annuler')),
              FilledButton(
                onPressed: saving ? null : () async {
                  bool isValid = true;
                  if (name.text.trim().isEmpty) {
                    setLocal(() => nameError = 'Le nom est requis');
                    isValid = false;
                  } else {
                    setLocal(() => nameError = null);
                  }
                  if (code.text.trim().isEmpty) {
                    setLocal(() => codeError = 'Le code est requis');
                    isValid = false;
                  } else {
                    setLocal(() => codeError = null);
                  }
                  if (!isValid) return;
                  setLocal(() => saving = true);
                  try {
                    final data = <String, dynamic>{
                      'name': name.text.trim(),
                      'code': code.text.trim(),
                      'type': type,
                      'address': address.text.trim().isEmpty ? null : address.text.trim(),
                      'phone': phone.text.trim().isEmpty ? null : phone.text.trim(),
                      'is_active': active,
                    };
                    if (location == null) {
                      await _service.create(data);
                    } else {
                      await _service.update(location.id, data);
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

  Future<void> _delete(Location loc) async {
    final confirmed = await confirmAction(
      context,
      title: 'Supprimer le lieu ?',
      message: 'Supprimer le lieu « ${loc.name} » ? Cette action est irréversible.',
      confirmLabel: 'Supprimer',
      danger: true,
    );
    if (!confirmed) return;
    
    try {
      await _service.delete(loc.id);
      _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(ApiClient.errorMessage(e)), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = AppSurface.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Lieux')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openForm(),
        icon: const Icon(Icons.add_location_alt),
        label: const Text('Nouveau'),
      ),
      body: _loading
          ? const SkeletonList()
          : _error != null
              ? EmptyState(icon: Icons.cloud_off, message: _error!, actionLabel: 'Réessayer', onAction: _load)
              : _items.isEmpty
                  ? EmptyState(icon: Icons.store_outlined, message: 'Aucun lieu.', actionLabel: 'Nouveau', onAction: () => _openForm())
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView.separated(
                        padding: const EdgeInsets.all(Insets.lg),
                        itemCount: _items.length,
                        separatorBuilder: (_, _) => const SizedBox(height: Insets.sm),
                        itemBuilder: (context, i) {
                          final loc = _items[i];
                          return AppCard(
                            padding: const EdgeInsets.symmetric(horizontal: Insets.md, vertical: Insets.xs),
                            child: ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: Icon(loc.isWarehouse ? Icons.warehouse : Icons.store, color: AppColors.brand),
                              title: Text(loc.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                              subtitle: Text('${loc.code} · ${loc.isWarehouse ? 'Dépôt' : 'Boutique'}${loc.isActive ? '' : ' · inactif'}',
                                  style: TextStyle(color: s.muted)),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(icon: const Icon(Icons.edit_outlined), onPressed: () => _openForm(location: loc)),
                                  IconButton(icon: const Icon(Icons.delete_outline), onPressed: () => _delete(loc)),
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
