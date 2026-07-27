import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Service pour le tracking d'analytics et de statistiques d'utilisation
class AnalyticsService {
  static final AnalyticsService _instance = AnalyticsService._internal();
  factory AnalyticsService() => _instance;
  AnalyticsService._internal();

  static const String _keyEvents = 'analytics_events';
  static const String _keyUserId = 'analytics_user_id';
  static const String _keySessionId = 'analytics_session_id';
  static const String _keyFirstLaunch = 'analytics_first_launch';
  static const String _keyLastLaunch = 'analytics_last_launch';
  static const int _maxEvents = 100;

  String? _userId;
  String? _sessionId;
  DateTime? _sessionStart;

  /// Initialiser le service
  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    _userId = prefs.getString(_keyUserId);
    
    if (_userId == null) {
      _userId = _generateId();
      await prefs.setString(_keyUserId, _userId!);
    }

    // Créer une nouvelle session
    _sessionId = _generateId();
    _sessionStart = DateTime.now();
    await prefs.setString(_keySessionId, _sessionId!);

    // Enregistrer le premier lancement
    if (!prefs.containsKey(_keyFirstLaunch)) {
      await prefs.setString(_keyFirstLaunch, DateTime.now().toIso8601String());
    }

    // Enregistrer le dernier lancement
    await prefs.setString(_keyLastLaunch, DateTime.now().toIso8601String());

    // Envoyer l'événement d'ouverture d'app
    await trackEvent('app_open', {
      'session_id': _sessionId,
      'first_launch': !prefs.containsKey(_keyFirstLaunch),
    });
  }

  /// Tracker un événement
  Future<void> trackEvent(String eventName, Map<String, dynamic>? properties) async {
    final event = {
      'event_name': eventName,
      'timestamp': DateTime.now().toIso8601String(),
      'user_id': _userId,
      'session_id': _sessionId,
      if (properties != null) ...properties,
    };

    if (kDebugMode) {
      print('[Analytics] $eventName: ${jsonEncode(properties ?? {})}');
    }

    await _saveEvent(event);
  }

  /// Tracker une vue d'écran
  Future<void> trackScreenView(String screenName) async {
    await trackEvent('screen_view', {
      'screen_name': screenName,
    });
  }

  /// Tracker une action utilisateur
  Future<void> trackUserAction(String action, Map<String, dynamic>? properties) async {
    await trackEvent('user_action', {
      'action': action,
      if (properties != null) ...properties,
    });
  }

  /// Tracker une erreur
  Future<void> trackError(String error, {String? stackTrace}) async {
    await trackEvent('error', {
      'error': error,
      if (stackTrace != null) 'stack_trace': stackTrace,
    });
  }

  /// Tracker une synchronisation
  Future<void> trackSync({
    required bool success,
    required int syncedCount,
    required int failedCount,
  }) async {
    await trackEvent('sync', {
      'success': success,
      'synced_count': syncedCount,
      'failed_count': failedCount,
    });
  }

  /// Tracker une création d'entité
  Future<void> trackEntityCreated(String entityType, String entityId) async {
    await trackEvent('entity_created', {
      'entity_type': entityType,
      'entity_id': entityId,
    });
  }

  /// Tracker une modification d'entité
  Future<void> trackEntityUpdated(String entityType, String entityId) async {
    await trackEvent('entity_updated', {
      'entity_type': entityType,
      'entity_id': entityId,
    });
  }

  /// Tracker une suppression d'entité
  Future<void> trackEntityDeleted(String entityType, String entityId) async {
    await trackEvent('entity_deleted', {
      'entity_type': entityType,
      'entity_id': entityId,
    });
  }

  /// Obtenir les statistiques de session
  Future<Map<String, dynamic>> getSessionStats() async {
    final prefs = await SharedPreferences.getInstance();
    final firstLaunch = prefs.getString(_keyFirstLaunch);
    final lastLaunch = prefs.getString(_keyLastLaunch);
    final events = await _getEvents();

    final sessionEvents = events.where((e) => e['session_id'] == _sessionId).toList();
    final screenViews = sessionEvents.where((e) => e['event_name'] == 'screen_view').length;
    final userActions = sessionEvents.where((e) => e['event_name'] == 'user_action').length;
    final errors = sessionEvents.where((e) => e['event_name'] == 'error').length;

    return {
      'user_id': _userId,
      'session_id': _sessionId,
      'session_duration': _sessionStart != null 
          ? DateTime.now().difference(_sessionStart!).inSeconds 
          : 0,
      'first_launch': firstLaunch,
      'last_launch': lastLaunch,
      'session_events': sessionEvents.length,
      'screen_views': screenViews,
      'user_actions': userActions,
      'errors': errors,
    };
  }

  /// Obtenir tous les événements stockés
  Future<List<Map<String, dynamic>>> getEvents() async {
    return await _getEvents();
  }

  /// Effacer tous les événements
  Future<void> clearEvents() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyEvents);
  }

  /// Sauvegarder un événement localement
  Future<void> _saveEvent(Map<String, dynamic> event) async {
    final prefs = await SharedPreferences.getInstance();
    final eventsJson = prefs.getString(_keyEvents) ?? '[]';
    final events = List<Map<String, dynamic>>.from(jsonDecode(eventsJson));

    events.add(event);

    // Garder seulement les N derniers événements
    if (events.length > _maxEvents) {
      events.removeRange(0, events.length - _maxEvents);
    }

    await prefs.setString(_keyEvents, jsonEncode(events));
  }

  /// Récupérer les événements stockés
  Future<List<Map<String, dynamic>>> _getEvents() async {
    final prefs = await SharedPreferences.getInstance();
    final eventsJson = prefs.getString(_keyEvents) ?? '[]';
    return List<Map<String, dynamic>>.from(jsonDecode(eventsJson));
  }

  /// Générer un ID unique
  String _generateId() {
    return '${DateTime.now().millisecondsSinceEpoch}-${_randomString(8)}';
  }

  /// Générer une chaîne aléatoire
  String _randomString(int length) {
    const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    final random = DateTime.now().millisecondsSinceEpoch;
    final sb = StringBuffer();
    for (var i = 0; i < length; i++) {
      sb.write(chars[(random + i) % chars.length]);
    }
    return sb.toString();
  }
}
