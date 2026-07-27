import 'package:flutter/material.dart';

/// Badge de statut générique (pilule colorée).
class StatusChip extends StatelessWidget {
  final String label;
  final Color color;
  const StatusChip({super.key, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(label,
          style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 12)),
    );
  }
}

({String label, Color color}) transferStatusInfo(String s) => switch (s) {
      'draft' => (label: 'Brouillon', color: Colors.grey),
      'dispatched' => (label: 'Expédié', color: Colors.purple),
      'received' => (label: 'Reçu', color: Colors.green),
      'cancelled' => (label: 'Annulé', color: Colors.red),
      _ => (label: s, color: Colors.grey),
    };

({String label, Color color}) purchaseStatusInfo(String s) => switch (s) {
      'draft' => (label: 'Brouillon', color: Colors.grey),
      'ordered' => (label: 'Commandé', color: Colors.blue),
      'received' => (label: 'Reçu', color: Colors.green),
      'cancelled' => (label: 'Annulé', color: Colors.red),
      _ => (label: s, color: Colors.grey),
    };

({String label, Color color}) inventoryStatusInfo(String s) => switch (s) {
      'open' => (label: 'Ouvert', color: Colors.grey),
      'counting' => (label: 'Comptage', color: Colors.orange),
      'closed' => (label: 'Clôturé', color: Colors.green),
      _ => (label: s, color: Colors.grey),
    };
