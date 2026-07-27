import 'package:flutter/material.dart';

import '../theme.dart';

/// Padding qui centre le contenu d'un formulaire (largeur lisible) sur grand écran,
/// via des marges horizontales calculées. À utiliser comme `padding:` d'un ListView
/// dans un écran poussé (plein écran).
EdgeInsets formPadding(BuildContext context, {double maxWidth = 620}) {
  final w = MediaQuery.of(context).size.width;
  final h = w > maxWidth + 2 * Insets.lg ? (w - maxWidth) / 2 : Insets.lg;
  return EdgeInsets.symmetric(horizontal: h, vertical: Insets.lg);
}

/// Centre et limite la largeur d'un contenu (formulaires) sur grand écran.
class FormWrap extends StatelessWidget {
  final Widget child;
  final double maxWidth;
  const FormWrap({super.key, required this.child, this.maxWidth = 620});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: child,
      ),
    );
  }
}

/// Grille responsive : calcule le nombre de colonnes selon la largeur
/// (1 sur mobile, plus sur grand écran) et dispose les enfants à largeur égale.
class ResponsiveWrap extends StatelessWidget {
  final List<Widget> children;
  final double minItemWidth;
  final double spacing;
  const ResponsiveWrap({
    super.key,
    required this.children,
    this.minItemWidth = 340,
    this.spacing = Insets.md,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final cols = ((c.maxWidth + spacing) / (minItemWidth + spacing)).floor().clamp(1, 4);
        final itemW = cols == 1 ? c.maxWidth : (c.maxWidth - (cols - 1) * spacing) / cols;
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            for (final child in children) SizedBox(width: itemW, child: child),
          ],
        );
      },
    );
  }
}

/// Deux panneaux : côte à côte sur grand écran, empilés sur mobile.
class TwoPane extends StatelessWidget {
  final Widget left;
  final Widget right;
  final int leftFlex;
  final int rightFlex;
  final double breakpoint;
  const TwoPane({
    super.key,
    required this.left,
    required this.right,
    this.leftFlex = 1,
    this.rightFlex = 1,
    this.breakpoint = 820,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        if (c.maxWidth < breakpoint) {
          return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [left, const SizedBox(height: Insets.lg), right]);
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(flex: leftFlex, child: left),
            const SizedBox(width: Insets.lg),
            Expanded(flex: rightFlex, child: right),
          ],
        );
      },
    );
  }
}
