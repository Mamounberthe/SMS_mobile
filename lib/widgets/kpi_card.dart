import 'package:flutter/material.dart';

import '../theme.dart';
import 'app_card.dart';

/// Tuile d'indicateur (KPI) : icône colorée + grande valeur + libellé.
class KpiCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const KpiCard({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final s = AppSurface.of(context);
    return AppCard(
      padding: const EdgeInsets.all(Insets.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(Radii.sm),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(height: Insets.md),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700, height: 1.1),
            ),
          ),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(fontSize: 13, color: s.muted)),
        ],
      ),
    );
  }
}
