import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../models/notification.dart';
import '../utils/validation.dart';
import 'api_client.dart';

class NotificationService {
  final ApiClient api;
  final FlutterLocalNotificationsPlugin localNotifications;
  NotificationService(this.api) : localNotifications = FlutterLocalNotificationsPlugin() {
    _initializeLocalNotifications();
  }

  /// Renvoie la liste + le nombre de non-lues (depuis meta.unread_count).
  Future<({List<AppNotification> items, int unread})> list({bool unreadOnly = false}) async {
    final res = await api.dio.get('/notifications', queryParameters: {
      if (unreadOnly) 'unread': 1,
    });
    final data = safeCastMapList(res.data['data']);
    final unread = (res.data['meta']?['unread_count'] ?? 0) as int;
    return (items: data.map(AppNotification.fromJson).toList(), unread: unread);
  }

  Future<void> markRead(int id) => api.dio.post('/notifications/$id/read');

  Future<void> markAllRead() => api.dio.post('/notifications/read-all');

  /// Initialiser les notifications locales
  Future<void> _initializeLocalNotifications() async {
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await localNotifications.initialize(initSettings);
  }

  /// Afficher une notification locale
  Future<void> showLocalNotification({
    required String title,
    required String body,
    String? payload,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      'rsms_channel',
      'RSMS Notifications',
      channelDescription: 'Notifications pour RSMS',
      importance: Importance.high,
      priority: Priority.high,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await localNotifications.show(
      DateTime.now().millisecondsSinceEpoch % 100000,
      title,
      body,
      notificationDetails,
      payload: payload,
    );
  }

  /// Notification de synchronisation réussie
  Future<void> notifySyncSuccess(int count) async {
    await showLocalNotification(
      title: 'Synchronisation réussie',
      body: '$count élément(s) synchronisé(s)',
    );
  }

  /// Notification de synchronisation échouée
  Future<void> notifySyncError(String error) async {
    await showLocalNotification(
      title: 'Erreur de synchronisation',
      body: error,
    );
  }

  /// Notification de sauvegarde hors-ligne
  Future<void> notifyOfflineSaved(String type) async {
    await showLocalNotification(
      title: 'Sauvegardé localement',
      body: '$type sauvegardé pour synchronisation ultérieure',
    );
  }

  /// Notification de reconnexion
  Future<void> notifyReconnected() async {
    await showLocalNotification(
      title: 'Connexion rétablie',
      body: 'Synchronisation automatique en cours...',
    );
  }

  /// Notification de stock faible
  Future<void> notifyLowStock(String productName, int quantity) async {
    await showLocalNotification(
      title: 'Stock faible',
      body: '$productName: $quantity unités restantes',
    );
  }

  /// Notification de produit expiré
  Future<void> notifyExpiringProduct(String productName, String expiryDate) async {
    await showLocalNotification(
      title: 'Produit expirant',
      body: '$productName expire le $expiryDate',
    );
  }
}
