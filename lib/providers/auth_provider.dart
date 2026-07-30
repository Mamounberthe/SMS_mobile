import 'package:flutter/foundation.dart';

import '../models/user.dart';
import '../services/api_client.dart';
import '../services/auth_service.dart';
import '../services/connectivity_service.dart';
import '../services/offline_service.dart';

enum AuthStatus { unknown, authenticated, unauthenticated }

/// État d'authentification partagé dans toute l'app.
///
/// Offline-resilient :
///  - au démarrage, si un token est présent mais que `/me` échoue **uniquement
///    à cause du réseau**, on restaure l'utilisateur depuis le cache SQLite
///    plutôt que de déconnecter (l'app reste utilisable hors-ligne) ;
///  - l'erreur 401 (token invalide/expiré) déclenche bien une déconnexion.
class AuthProvider extends ChangeNotifier {
  final AuthService _auth;
  final ApiClient _api;
  final ConnectivityService _connectivity;
  final OfflineService _offline;

  AuthProvider(this._auth, this._api, this._connectivity, this._offline) {
    _bootstrap();
  }

  /// Déconnexion forcée (appelée automatiquement en cas d'erreur 401).
  void forceLogout() {
    user = null;
    status = AuthStatus.unauthenticated;
    error = 'Session expirée. Veuillez vous reconnecter.';
    // Ne purger QUE la session, PAS les opérations offline en attente
    _offline.clearSession(); // supprime current_user + token uniquement
    notifyListeners();
  }

  AuthStatus status = AuthStatus.unknown;
  User? user;
  String? error;
  bool loading = false;

  /// Au démarrage : y a-t-il un token valide déjà stocké ?
  Future<void> _bootstrap() async {
    // Attendre que le état réseau réel soit résolu avant de décider
    await Future.delayed(const Duration(milliseconds: 500));

    final token = await _api.readToken();
    if (token == null || token.isEmpty) {
      status = AuthStatus.unauthenticated;
      notifyListeners();
      return;
    }
    try {
      user = await _auth.me();
      status = AuthStatus.authenticated;
      // Mettre à jour le cache pour les futurs démarrages hors-ligne.
      await _offline.cacheCurrentUser(user!);
    } catch (e) {
      // Si on est hors-ligne, on ne déconnecte pas : on restaure la session
      // depuis le cache pour permettre l'usage offline-first.
      if (_connectivity.isOffline) {
        final cached = await _offline.getCachedCurrentUser();
        if (cached != null) {
          user = cached;
          status = AuthStatus.authenticated;
        } else {
          await _api.clearToken();
          status = AuthStatus.unauthenticated;
        }
      } else {
        // En ligne et échec /me → token réellement invalide : déconnexion.
        await _api.clearToken();
        status = AuthStatus.unauthenticated;
      }
    }
    notifyListeners();
  }

  Future<bool> login(String email, String password) async {
    loading = true;
    error = null;
    notifyListeners();
    try {
      user = await _auth.login(email, password);
      status = AuthStatus.authenticated;
      await _offline.cacheCurrentUser(user!);
      return true;
    } catch (e) {
      error = ApiClient.errorMessage(e);
      return false;
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<void> logout() async {
    // En hors-ligne, l'appel /logout échouera ; on purge quand même localement.
    try {
      await _auth.logout();
    } catch (_) {
      await _api.clearToken();
    }
    await _offline.clearAll();
    user = null;
    status = AuthStatus.unauthenticated;
    notifyListeners();
  }
}
