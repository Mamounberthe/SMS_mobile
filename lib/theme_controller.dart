import 'package:flutter/material.dart';

/// Contrôle le mode de thème (système / clair / sombre) — feature premium.
class ThemeController extends ChangeNotifier {
  ThemeMode _mode = ThemeMode.system;
  ThemeMode get mode => _mode;

  /// Bascule clair <-> sombre (part du rendu courant).
  void toggle(Brightness current) {
    _mode = current == Brightness.dark ? ThemeMode.light : ThemeMode.dark;
    notifyListeners();
  }

  void setMode(ThemeMode mode) {
    _mode = mode;
    notifyListeners();
  }

  bool get isDark => _mode == ThemeMode.dark;
}
