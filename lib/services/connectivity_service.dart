import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

/// Source unique de vérité sur l'état de la connexion réseau.
///
/// Centralise `connectivity_plus` pour éviter que chaque écran réécoute
/// `onConnectivityChanged` (ce qui créait plusieurs subscriptions fuyantes et
/// des déductions d'état contradictoires entre écrans).
///
/// En `connectivity_plus` v6, `checkConnectivity()` renvoie une
/// `List<ConnectivityResult>` — l'ancien code des écrans comparait
/// `result == ConnectivityResult.none` (un enum contre une liste), ce qui
/// rendait `_isOffline` toujours faux. Ce service corrige ce bug.
class ConnectivityService extends ChangeNotifier {
  ConnectivityService() {
    _init();
  }

  bool _isOnline = true;
  final List<StreamSubscription<List<ConnectivityResult>>> _subs = [];

  /// `true` si l'appareil a au moins une connexion (wifi/mobile/ethernet…).
  bool get isOnline => _isOnline;

  /// `true` si hors-ligne (aucune connexion).
  bool get isOffline => !_isOnline;

  void _init() {
    // État initial (asynchrone).
    Connectivity().checkConnectivity().then((results) {
      _isOnline = _hasConnection(results);
      notifyListeners();
    });

    // Changements ultérieurs.
    _subs.add(Connectivity().onConnectivityChanged.listen((results) {
      final online = _hasConnection(results);
      if (online != _isOnline) {
        _isOnline = online;
        notifyListeners();
      }
    }));
  }

  /// Une liste de résultats contient-elle une connexion utilisable ?
  /// `none` = aucun réseau ; les autres (wifi, mobile, ethernet…) = connecté.
  static bool _hasConnection(List<ConnectivityResult> results) {
    if (results.isEmpty) return false;
    // On est online si au moins un résultat n'est pas `none` (et pas `bluetooth`
    // seul, qui n'est pas une connexion IP fiable).
    return results.any(
      (r) => r != ConnectivityResult.none && r != ConnectivityResult.bluetooth,
    );
  }

  /// Force une vérification immédiate (utile avant une action critique).
  Future<void> recheck() async {
    final results = await Connectivity().checkConnectivity();
    final online = _hasConnection(results);
    if (online != _isOnline) {
      _isOnline = online;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    for (final s in _subs) {
      s.cancel();
    }
    super.dispose();
  }
}
