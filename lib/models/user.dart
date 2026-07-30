/// Modèle utilisateur — miroir Dart du UserResource de l'API.
import '../utils/validation.dart';

class User {
  final int id;
  final String name;
  final String email;
  final String role;
  final String roleLabel;
  final int? locationId;
  final bool isActive;

  User({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    required this.roleLabel,
    this.locationId,
    this.isActive = true,
  });

  /// Construit un User depuis le JSON de l'API.
  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] as int,
      name: json['name'] as String,
      email: json['email'] as String,
      role: json['role'] as String,
      roleLabel: (json['role_label'] ?? json['role']) as String,
      locationId: json['location_id'] as int?,
      isActive: parseBool(json['is_active'] ?? true),
    );
  }
}
