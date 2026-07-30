import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/location.dart';
import '../models/user.dart';
import '../services/api_client.dart';
import '../services/reference_service.dart';
import '../services/user_service.dart';
import '../services/offline_service.dart';
import '../theme.dart';
import '../widgets/app_card.dart';
import '../widgets/confirm_dialog.dart';
import '../widgets/empty_state.dart';
import '../widgets/skeleton.dart';

const _roles = {
  'admin': 'Administrateur',
  'director': 'Directeur',
  'storekeeper': 'Magasinier',
  'store_manager': 'Responsable Boutique',
};

/// Gestion des utilisateurs & rôles (réservé admin).
class UsersScreen extends StatefulWidget {
  const UsersScreen({super.key});

  @override
  State<UsersScreen> createState() => _UsersScreenState();
}

class _UsersScreenState extends State<UsersScreen> {
  late final UserService _service;
  late final ReferenceService _ref;
  List<User> _items = [];
  List<Location> _locations = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _service = UserService(context.read<ApiClient>());
    _ref = ReferenceService(context.read<ApiClient>(), context.read<OfflineService>());
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await _service.list();
      final locs = await _ref.locations();
      if (mounted) {
        setState(() {
          _items = res.items;
          _locations = locs;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = ApiClient.errorMessage(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openForm({User? user}) async {
    final name = TextEditingController(text: user?.name ?? '');
    final email = TextEditingController(text: user?.email ?? '');
    final password = TextEditingController();
    String role = user?.role ?? 'store_manager';
    int? locationId = user?.locationId;
    bool active = user?.isActive ?? true;
    String? nameError;
    String? emailError;
    String? passwordError;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        bool saving = false;
        return StatefulBuilder(
          builder: (ctx, setLocal) => AlertDialog(
            title: Text(user == null ? 'Nouvel utilisateur' : 'Modifier l\'utilisateur'),
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
                    controller: email,
                    decoration: InputDecoration(
                      labelText: 'Email *',
                      errorText: emailError,
                    ),
                    keyboardType: TextInputType.emailAddress,
                    enabled: !saving,
                  ),
                  const SizedBox(height: Insets.sm),
                  TextField(
                    controller: password,
                    decoration: InputDecoration(
                      labelText: user == null ? 'Mot de passe *' : 'Mot de passe (laisser vide = inchangé)',
                      helperText: '8+ car., majuscule, minuscule, chiffre',
                      errorText: passwordError,
                    ),
                    obscureText: true,
                    enabled: !saving,
                  ),
                  const SizedBox(height: Insets.sm),
                  DropdownButtonFormField<String>(
                    initialValue: role,
                    decoration: const InputDecoration(labelText: 'Rôle *', prefixIcon: Icon(Icons.badge)),
                    items: _roles.entries.map((e) => DropdownMenuItem(value: e.key, child: Text(e.value))).toList(),
                    onChanged: saving ? null : (v) => setLocal(() => role = v ?? role),
                  ),
                  const SizedBox(height: Insets.sm),
                  DropdownButtonFormField<int?>(
                    initialValue: locationId,
                    decoration: const InputDecoration(labelText: 'Lieu rattaché', prefixIcon: Icon(Icons.place)),
                    items: [
                      const DropdownMenuItem<int?>(value: null, child: Text('— (siège / global)')),
                      ..._locations.map((l) => DropdownMenuItem(value: l.id, child: Text(l.name))),
                    ],
                    onChanged: saving ? null : (v) => setLocal(() => locationId = v),
                  ),
                  SwitchListTile(
                    value: active,
                    onChanged: saving ? null : (v) => setLocal(() => active = v),
                    title: const Text('Compte actif'),
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
                  if (email.text.trim().isEmpty) {
                    setLocal(() => emailError = 'L\'email est requis');
                    isValid = false;
                  } else if (!email.text.trim().contains('@')) {
                    setLocal(() => emailError = 'Email invalide');
                    isValid = false;
                  } else {
                    setLocal(() => emailError = null);
                  }
                  if (user == null && password.text.isEmpty) {
                    setLocal(() => passwordError = 'Le mot de passe est requis');
                    isValid = false;
                  } else {
                    setLocal(() => passwordError = null);
                  }
                  if (!isValid) return;
                  setLocal(() => saving = true);
                  try {
                    final data = <String, dynamic>{
                      'name': name.text.trim(),
                      'email': email.text.trim(),
                      'role': role,
                      'location_id': locationId,
                      'is_active': active,
                    };
                    if (password.text.isNotEmpty) data['password'] = password.text;
                    if (user == null) {
                      await _service.create(data);
                    } else {
                      await _service.update(user.id, data);
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

  Future<void> _delete(User u) async {
    final confirmed = await confirmAction(
      context,
      title: 'Supprimer l\'utilisateur ?',
      message: 'Supprimer l\'utilisateur « ${u.name} » ? Cette action est irréversible.',
      confirmLabel: 'Supprimer',
      danger: true,
    );
    if (!confirmed) return;
    
    try {
      await _service.delete(u.id);
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
      appBar: AppBar(title: const Text('Utilisateurs')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openForm(),
        icon: const Icon(Icons.person_add),
        label: const Text('Nouveau'),
      ),
      body: _loading
          ? const SkeletonList()
          : _error != null
              ? EmptyState(icon: Icons.cloud_off, message: _error!, actionLabel: 'Réessayer', onAction: _load)
              : _items.isEmpty
                  ? const EmptyState(icon: Icons.people_outline, message: 'Aucun utilisateur.')
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView.separated(
                        padding: const EdgeInsets.all(Insets.lg),
                        itemCount: _items.length,
                        separatorBuilder: (_, _) => const SizedBox(height: Insets.sm),
                        itemBuilder: (context, i) {
                          final u = _items[i];
                          return AppCard(
                            padding: const EdgeInsets.symmetric(horizontal: Insets.md, vertical: Insets.xs),
                            child: ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: CircleAvatar(
                                backgroundColor: AppColors.brand.withValues(alpha: 0.15),
                                child: Text(u.name.isNotEmpty ? u.name[0].toUpperCase() : '?',
                                    style: const TextStyle(color: AppColors.brand, fontWeight: FontWeight.bold)),
                              ),
                              title: Row(
                                children: [
                                  Flexible(child: Text(u.name, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600))),
                                  if (!u.isActive) ...[
                                    const SizedBox(width: Insets.sm),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                      decoration: BoxDecoration(color: Colors.red.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(Radii.pill)),
                                      child: const Text('inactif', style: TextStyle(fontSize: 10, color: Colors.red)),
                                    ),
                                  ],
                                ],
                              ),
                              subtitle: Text('${u.roleLabel} · ${u.email}', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: s.muted)),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(icon: const Icon(Icons.edit_outlined), onPressed: () => _openForm(user: u)),
                                  IconButton(icon: const Icon(Icons.delete_outline), onPressed: () => _delete(u)),
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
