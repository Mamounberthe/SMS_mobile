import 'package:flutter/material.dart';

import '../theme.dart';

/// En-tête de page (style web/ERP) : titre + sous-titre + actions à droite.
/// Placé en haut du corps d'un écran de module.
class PageHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final List<Widget> actions;

  const PageHeader({super.key, required this.title, this.subtitle, this.actions = const []});

  @override
  Widget build(BuildContext context) {
    final s = AppSurface.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: Insets.lg),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
                if (subtitle != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(subtitle!, style: TextStyle(color: s.muted, fontSize: 13)),
                  ),
              ],
            ),
          ),
          ...actions,
        ],
      ),
    );
  }
}
