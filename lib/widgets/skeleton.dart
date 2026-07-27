import 'package:flutter/material.dart';

import '../theme.dart';

/// Effet "shimmer" (balayage lumineux) appliqué à ses enfants.
class Shimmer extends StatefulWidget {
  final Widget child;
  const Shimmer({super.key, required this.child});

  @override
  State<Shimmer> createState() => _ShimmerState();
}

class _ShimmerState extends State<Shimmer> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final base = dark ? Colors.white10 : Colors.black.withValues(alpha: 0.06);
    final highlight = dark ? Colors.white24 : Colors.black.withValues(alpha: 0.12);
    return AnimatedBuilder(
      animation: _c,
      builder: (context, child) {
        return ShaderMask(
          blendMode: BlendMode.srcATop,
          shaderCallback: (bounds) {
            final dx = bounds.width * (2 * _c.value - 1);
            return LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [base, highlight, base],
              stops: const [0.35, 0.5, 0.65],
              transform: _SlideGradient(dx),
            ).createShader(bounds);
          },
          child: child,
        );
      },
      child: widget.child,
    );
  }
}

class _SlideGradient extends GradientTransform {
  final double dx;
  const _SlideGradient(this.dx);
  @override
  Matrix4? transform(Rect bounds, {TextDirection? textDirection}) => Matrix4.translationValues(dx, 0, 0);
}

/// Bloc gris arrondi (brique de base des squelettes).
class SkeletonBox extends StatelessWidget {
  final double? width;
  final double height;
  final double radius;
  const SkeletonBox({super.key, this.width, this.height = 14, this.radius = Radii.sm});

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: dark ? Colors.white12 : Colors.black.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}

/// Liste de cartes-squelettes imitant une liste de lignes (produits, commandes…).
class SkeletonList extends StatelessWidget {
  final int count;
  final EdgeInsetsGeometry padding;
  const SkeletonList({super.key, this.count = 7, this.padding = const EdgeInsets.all(Insets.xl)});

  @override
  Widget build(BuildContext context) {
    final s = AppSurface.of(context);
    return Shimmer(
      child: ListView.separated(
        padding: padding,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: count,
        separatorBuilder: (_, _) => const SizedBox(height: Insets.md),
        itemBuilder: (_, _) => Container(
          padding: const EdgeInsets.all(Insets.md),
          decoration: BoxDecoration(
            color: s.surface,
            borderRadius: BorderRadius.circular(Radii.md),
            border: Border.all(color: s.border),
          ),
          child: Row(
            children: [
              const SkeletonBox(width: 44, height: 44, radius: Radii.md),
              const SizedBox(width: Insets.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    SkeletonBox(width: 180, height: 13),
                    SizedBox(height: 8),
                    SkeletonBox(width: 110, height: 11),
                  ],
                ),
              ),
              const SizedBox(width: Insets.md),
              const SkeletonBox(width: 54, height: 22, radius: Radii.pill),
            ],
          ),
        ),
      ),
    );
  }
}

/// Grille de tuiles-squelettes (KPI du tableau de bord).
class SkeletonGrid extends StatelessWidget {
  final int count;
  final int columns;
  const SkeletonGrid({super.key, this.count = 8, this.columns = 4});

  @override
  Widget build(BuildContext context) {
    final s = AppSurface.of(context);
    return Shimmer(
      child: GridView.count(
        crossAxisCount: columns,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: Insets.lg,
        crossAxisSpacing: Insets.lg,
        childAspectRatio: 1.55,
        children: List.generate(
          count,
          (_) => Container(
            padding: const EdgeInsets.all(Insets.lg),
            decoration: BoxDecoration(
              color: s.surface,
              borderRadius: BorderRadius.circular(Radii.md),
              border: Border.all(color: s.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: const [
                SkeletonBox(width: 40, height: 40, radius: Radii.sm),
                SkeletonBox(width: 70, height: 20),
                SkeletonBox(width: 90, height: 11),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
