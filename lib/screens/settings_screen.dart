import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../services/localization_service.dart';
import '../theme.dart';
import '../theme_controller.dart';
import '../widgets/app_card.dart';

/// Écran des paramètres de l'application
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _syncNotifEnabled = true;
  bool _stockAlertEnabled = true;

  @override
  Widget build(BuildContext context) {
    final s = AppSurface.of(context);
    final themeController = context.watch<ThemeController>();
    final localizationService = context.watch<LocalizationService>();
    final auth = context.watch<AuthProvider>();

    return Scaffold(
      appBar: AppBar(title: const Text('Paramètres')),
      body: ListView(
        padding: const EdgeInsets.all(Insets.xl),
        children: [
          // Section Apparence
          _buildSectionHeader('Apparence', s),
          const SizedBox(height: Insets.md),
          AppCard(
            child: Column(
              children: [
                Material(
                  color: Colors.transparent,
                  child: ListTile(
                    leading: Icon(Icons.dark_mode, color: AppColors.brand),
                    title: const Text('Mode sombre'),
                    trailing: Switch(
                      value: themeController.mode == ThemeMode.dark,
                      onChanged: (value) {
                        themeController.setMode(value ? ThemeMode.dark : ThemeMode.light);
                      },
                    ),
                  ),
                ),
                const Divider(height: 1),
                Material(
                  color: Colors.transparent,
                  child: ListTile(
                    leading: Icon(Icons.language, color: AppColors.brand),
                    title: const Text('Langue'),
                    trailing: DropdownButton<String>(
                      value: localizationService.currentLocale.languageCode,
                      items: const [
                        DropdownMenuItem(value: 'fr', child: Text('Français')),
                        DropdownMenuItem(value: 'en', child: Text('English')),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          localizationService.setLocale(value);
                        }
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: Insets.xl),

          // Section Notifications
          _buildSectionHeader('Notifications', s),
          const SizedBox(height: Insets.md),
          AppCard(
            child: Column(
              children: [
                Material(
                  color: Colors.transparent,
                  child: ListTile(
                    leading: Icon(Icons.sync, color: AppColors.brand),
                    title: const Text('Notifications de synchronisation'),
                    trailing: Switch(
                      value: _syncNotifEnabled,
                      onChanged: (v) {
                        setState(() => _syncNotifEnabled = v);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(v ? 'Notifications de synchronisation activées' : 'Notifications de synchronisation désactivées')),
                        );
                      },
                    ),
                  ),
                ),
                const Divider(height: 1),
                Material(
                  color: Colors.transparent,
                  child: ListTile(
                    leading: Icon(Icons.inventory_2, color: AppColors.brand),
                    title: const Text('Alertes de stock faible'),
                    trailing: Switch(
                      value: _stockAlertEnabled,
                      onChanged: (v) {
                        setState(() => _stockAlertEnabled = v);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(v ? 'Alertes de stock faible activées' : 'Alertes de stock faible désactivées')),
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: Insets.xl),

          // Section Compte
          _buildSectionHeader('Compte', s),
          const SizedBox(height: Insets.md),
          AppCard(
            child: Column(
              children: [
                Material(
                  color: Colors.transparent,
                  child: ListTile(
                    leading: const Icon(Icons.person),
                    title: Text(auth.user?.name ?? 'Utilisateur'),
                    subtitle: Text(auth.user?.email ?? ''),
                  ),
                ),
                const Divider(height: 1),
                Material(
                  color: Colors.transparent,
                  child: ListTile(
                    leading: const Icon(Icons.logout, color: Colors.red),
                    title: const Text('Déconnexion', style: TextStyle(color: Colors.red)),
                    onTap: () {
                      auth.logout();
                    },
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: Insets.xl),

          // Section Info
          _buildSectionHeader('Informations', s),
          const SizedBox(height: Insets.md),
          AppCard(
            child: Column(
              children: [
                Material(
                  color: Colors.transparent,
                  child: ListTile(
                    leading: const Icon(Icons.info_outline),
                    title: const Text('Version de l\'application'),
                    subtitle: const Text('2.0.0'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, AppSurface s) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: s.muted,
      ),
    );
  }
}
