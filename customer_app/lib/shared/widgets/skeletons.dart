import 'package:flutter/material.dart';
import 'package:jivo_core/jivo_core.dart';

/// Static grey placeholders shown while content loads (`03 §4`). They never
/// animate, so tests can settle.
class SkeletonBox extends StatelessWidget {
  const SkeletonBox({this.width, this.height, this.radius, super.key});

  final double? width;
  final double? height;
  final double? radius;

  @override
  Widget build(BuildContext context) => Container(
    width: width,
    height: height,
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(radius ?? JivoRadii.sm),
    ),
  );
}

/// Announces "loading" once and hides the placeholder shapes from screen
/// readers.
class SkeletonSemantics extends StatelessWidget {
  const SkeletonSemantics({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) => Semantics(
    label: MaterialLocalizations.of(context).refreshIndicatorSemanticLabel,
    child: ExcludeSemantics(child: child),
  );
}

/// A grid of product-tile placeholders.
class ProductGridSkeleton extends StatelessWidget {
  const ProductGridSkeleton({this.count = 6, super.key});

  final int count;

  @override
  Widget build(BuildContext context) => SkeletonSemantics(
    child: GridView.builder(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.all(JivoSpacing.sm),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 200,
        mainAxisExtent: 260,
        crossAxisSpacing: JivoSpacing.sm,
        mainAxisSpacing: JivoSpacing.sm,
      ),
      itemCount: count,
      itemBuilder: (_, _) => const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SkeletonBox(height: 110, width: double.infinity),
          SizedBox(height: JivoSpacing.sm),
          SkeletonBox(height: 14, width: double.infinity),
          SizedBox(height: JivoSpacing.xs),
          SkeletonBox(height: 14, width: 80),
          Spacer(),
          SkeletonBox(height: 40, width: double.infinity),
        ],
      ),
    ),
  );
}

/// The home layout in grey: header, search bar, banner, categories, a rail.
class HomeSkeleton extends StatelessWidget {
  const HomeSkeleton({super.key});

  @override
  Widget build(BuildContext context) => SkeletonSemantics(
    child: ListView(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.all(JivoSpacing.gutter),
      children: [
        const SkeletonBox(height: 140, width: double.infinity),
        const SizedBox(height: JivoSpacing.xl),
        const SkeletonBox(height: 18, width: 160),
        const SizedBox(height: JivoSpacing.md),
        Row(
          children: [
            for (var i = 0; i < 4; i++) ...[
              if (i > 0) const SizedBox(width: JivoSpacing.md),
              const Expanded(child: SkeletonBox(height: 72)),
            ],
          ],
        ),
        const SizedBox(height: JivoSpacing.xl),
        const SkeletonBox(height: 18, width: 120),
        const SizedBox(height: JivoSpacing.md),
        Row(
          children: [
            for (var i = 0; i < 2; i++) ...[
              if (i > 0) const SizedBox(width: JivoSpacing.md),
              const Expanded(child: SkeletonBox(height: 200)),
            ],
          ],
        ),
      ],
    ),
  );
}
