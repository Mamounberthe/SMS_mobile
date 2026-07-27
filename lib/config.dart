/// Configuration globale de l'application.
class AppConfig {
  /// URL de base de l'API RSMS.
  ///
  /// Par défaut : API locale (dev ET release local). Pour la vraie production,
  /// surcharger au build :
  ///   flutter build web --release --dart-define=API_BASE_URL=https://mon-api.com/api/v1
  ///
  /// Selon la cible :
  /// - Web (Chrome)      : http://127.0.0.1:8000
  /// - Émulateur Android : http://10.0.2.2:8000 (10.0.2.2 = localhost de la machine hôte)
  /// - Appareil physique : http://[IP-de-ton-PC]:8000
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://127.0.0.1:8000/api/v1',
  );
}
