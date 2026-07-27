/// Notification d'alerte — miroir de NotificationResource.
class AppNotification {
  final int id;
  final String type; // low_stock | out_of_stock | expired | near_expiry | order_status
  final String title;
  final String? body;
  final bool read;

  AppNotification({
    required this.id,
    required this.type,
    required this.title,
    this.body,
    required this.read,
  });

  factory AppNotification.fromJson(Map<String, dynamic> json) => AppNotification(
        id: json['id'] as int,
        type: json['type'] as String,
        title: json['title'] as String,
        body: json['body'] as String?,
        read: json['read_at'] != null,
      );
}
