import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/category.dart';
import '../services/api_client.dart';
import '../services/category_service.dart';
import '../theme.dart';
import '../widgets/app_card.dart';
import '../widgets/confirm_dialog.dart';
import '../widgets/empty_state.dart';
import '../widgets/skeleton.dart';

/// Gestion des catégories (CRUD) — écran poussé depuis l'Administration.
class CategoriesScreen extends StatefulWidget {
  const CategoriesScreen({super.key});

  @override
  State<CategoriesScreen> createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends State<CategoriesScreen> {
  late final CategoryService _service;
  List<Category> _items = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _service = CategoryService(context.read<ApiClient>());
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

  Future<void> _openForm({Category? category}) async {
    final nameCtrl = TextEditingController(text: category?.name ?? '');
    final descCtrl = TextEditingController(text: category?.description ?? '');
    String? validationError;
    
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        bool saving = false;
        return StatefulBuilder(
          builder: (ctx, setLocal) => AlertDialog(
            title: Text(category == null ? 'Nouvelle catégorie' : 'Modifier la catégorie'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtrl,
                  autofocus: true,
                  decoration: InputDecoration(
                    labelText: 'Nom *',
                    errorText: validationError,
                  ),
                  enabled: !saving,
                ),
                const SizedBox(height: Insets.md),
                TextField(controller: descCtrl, decoration: const InputDecoration(labelText: 'Description'), maxLines: 2, enabled: !saving),
              ],
            ),
            actions: [
              TextButton(onPressed: saving ? null : () => Navigator.pop(ctx, false), child: const Text('Annuler')),
              FilledButton(
                onPressed: saving ? null : () async {
                  if (nameCtrl.text.trim().isEmpty) {
                    setLocal(() => validationError = 'Le nom est requis');
                    return;
                  }
                  setLocal(() => saving = true);
                  try {
                    final data = {
                      'name': nameCtrl.text.trim(),
                      'description': descCtrl.text.trim().isEmpty ? null : descCtrl.text.trim(),
                    };
                    if (category == null) {
                      await _service.create(data);
                    } else {
                      await _service.update(category.id, data);
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

  Future<void> _delete(Category c) async {
    final confirmed = await confirmAction(
      context,
      title: 'Supprimer la catégorie ?',
      message: 'Supprimer la catégorie « ${c.name} » ? Cette action est irréversible.',
      confirmLabel: 'Supprimer',
      danger: true,
    );
    if (!confirmed) return;
    
    try {
      await _service.delete(c.id);
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
      appBar: AppBar(title: const Text('Catégories')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openForm(),
        icon: const Icon(Icons.add),
        label: const Text('Nouvelle'),
      ),
      body: _loading
          ? const SkeletonList()
          : _error != null
              ? EmptyState(icon: Icons.cloud_off, message: _error!, actionLabel: 'Réessayer', onAction: _load)
              : _items.isEmpty
                  ? EmptyState(icon: Icons.category_outlined, message: 'Aucune catégorie.', actionLabel: 'Nouvelle', onAction: () => _openForm())
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView.separated(
                        padding: const EdgeInsets.all(Insets.lg),
                        itemCount: _items.length,
                        separatorBuilder: (_, _) => const SizedBox(height: Insets.sm),
                        itemBuilder: (context, i) {
                          final c = _items[i];
                          return AppCard(
                            padding: const EdgeInsets.symmetric(horizontal: Insets.md, vertical: Insets.xs),
                            child: ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: const Icon(Icons.category, color: AppColors.brand),
                              title: Text(c.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                              subtitle: c.description != null ? Text(c.description!, style: TextStyle(color: s.muted)) : null,
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(icon: const Icon(Icons.edit_outlined), onPressed: () => _openForm(category: c)),
                                  IconButton(icon: const Icon(Icons.delete_outline), onPressed: () => _delete(c)),
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
