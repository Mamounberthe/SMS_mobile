/// Fournisseur — miroir de SupplierResource.
import '../utils/validation.dart';

class Supplier {
  final int id;
  final String name;
  final String? contactName;
  final String? phone;
  final String? email;
  final String? address;
  final bool isActive;

  Supplier({
    required this.id,
    required this.name,
    this.contactName,
    this.phone,
    this.email,
    this.address,
    this.isActive = true,
  });

  factory Supplier.fromJson(Map<String, dynamic> json) => Supplier(
        id: json['id'] as int,
        name: json['name'] as String,
        contactName: json['contact_name'] as String?,
        phone: json['phone'] as String?,
        email: json['email'] as String?,
        address: json['address'] as String?,
        isActive: parseBool(json['is_active'] ?? true),
      );
}
