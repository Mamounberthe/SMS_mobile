/// Lieu (dépôt ou boutique) — miroir de LocationResource.
import '../utils/validation.dart';

class Location {
  final int id;
  final String name;
  final String code;
  final String type; // 'warehouse' | 'store'
  final String? address;
  final String? phone;
  final bool isActive;

  Location({
    required this.id,
    required this.name,
    required this.code,
    required this.type,
    this.address,
    this.phone,
    this.isActive = true,
  });

  factory Location.fromJson(Map<String, dynamic> json) => Location(
        id: json['id'] as int,
        name: json['name'] as String,
        code: json['code'] as String,
        type: json['type'] as String,
        address: json['address'] as String?,
        phone: json['phone'] as String?,
        isActive: parseBool(json['is_active'] ?? true),
      );

  bool get isWarehouse => type == 'warehouse';
}
