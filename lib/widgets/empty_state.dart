import 'package:flutter/material.dart';

import '../theme.dart';

/// État vide / erreur uniforme : icône + message + action optionnelle.
class EmptyState extends StatelessWidget {
  final IconData icon;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  const EmptyState({
    super.key,
    required this.icon,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final s = AppSurface.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(Insets.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(color: s.surfaceAlt, borderRadius: BorderRadius.circular(Radii.lg)),
              child: Icon(icon, size: 30, color: s.muted),
            ),
            const SizedBox(height: Insets.lg),
            Text(message, textAlign: TextAlign.center, style: TextStyle(color: s.muted)),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: Insets.lg),
              FilledButton.tonal(onPressed: onAction, child: Text(actionLabel!)),
            ],
          ],
        ),
      ),
    );
  }
}
