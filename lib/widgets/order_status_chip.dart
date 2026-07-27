import 'package:flutter/material.dart';

/// Libellé + couleur d'un statut de commande. Réutilisé dans la liste et le détail.
({String label, Color color}) orderStatusInfo(String status) {
  return switch (status) {
    'draft' => (label: 'Brouillon', color: Colors.grey),
    'sent' => (label: 'Envoyée', color: Colors.blue),
    'validated' => (label: 'Validée', color: Colors.indigo),
    'prepared' => (label: 'Préparée', color: Colors.orange),
    'shipped' => (label: 'Expédiée', color: Colors.purple),
    'received' => (label: 'Reçue', color: Colors.green),
    'cancelled' => (label: 'Annulée', color: Colors.red),
    _ => (label: status, color: Colors.grey),
  };
}

class OrderStatusChip extends StatelessWidget {
  final String status;
  const OrderStatusChip({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    final info = orderStatusInfo(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: info.color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: info.color.withValues(alpha: 0.4)),
      ),
      child: Text(
        info.label,
        style: TextStyle(color: info.color, fontWeight: FontWeight.w600, fontSize: 12),
      ),
    );
  }
}
