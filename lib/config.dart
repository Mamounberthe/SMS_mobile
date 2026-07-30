import 'package:flutter/foundation.dart';

/// Configuration globale de l'application.
class AppConfig {
  /// URL de base de l'API RSMS.
  /// En release, OBLIGATOIRE de passer --dart-define=API_BASE_URL=https://...
  /// (HTTPS requis pour ne pas exposer les credentials en clair).
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: kDebugMode
        ? 'http://10.0.2.2:8000/api/v1' // émulateur Android seulement
        : 'https://api.rsms.app/api/v1', // fallback HTTPS en release
  );

  /// Vérifie au démarrage que l'URL est valide.
  static void validate() {
    if (!apiBaseUrl.startsWith('https://') && !apiBaseUrl.startsWith('http://')) {
      throw StateError(
        'API_BASE_URL invalide ($apiBaseUrl). '
        'Passez --dart-define=API_BASE_URL=https://votre-api.com/api/v1',
      );
    }
  }
}
