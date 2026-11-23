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

/// The home layout in grey, shaped like the real sections (home redesign):
/// the featured banner, the category row and a rail of two product cards.
/// The header and search field are real and stay above it.
class HomeSkeleton extends StatelessWidget {
  const HomeSkeleton({super.key});

  @override
  Widget build(BuildContext context) => SkeletonSemantics(
    child: ListView(
      key: const Key('home-skeleton'),
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: JivoSpacing.gutter),
      children: [
        const SkeletonBox(
          height: 140,
          width: double.infinity,
          radius: JivoRadii.lg,
        ),
        const SizedBox(height: JivoSpacing.xl),
        const SkeletonBox(height: 16, width: 140),
        const SizedBox(height: JivoSpacing.md),
        SizedBox(
          height: 90,
          child: ClipRect(
            child: OverflowBox(
              alignment: Alignment.centerLeft,
              maxWidth: double.infinity,
              child: Row(
                children: [
                  for (var i = 0; i < 6; i++) ...[
                    if (i > 0) const SizedBox(width: JivoSpacing.md),
                    const Column(
                      children: [
                        SkeletonBox(
                          height: 64,
                          width: 64,
                          radius: JivoRadii.lg,
                        ),
                        SizedBox(height: JivoSpacing.sm),
                        SkeletonBox(height: 10, width: 52),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: JivoSpacing.xl),
        const SkeletonBox(height: 16, width: 120),
        const SizedBox(height: JivoSpacing.md),
        Row(
          children: [
            for (var i = 0; i < 2; i++) ...[
              if (i > 0) const SizedBox(width: JivoSpacing.md),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SkeletonBox(
                      height: 112,
                      width: double.infinity,
                      radius: JivoRadii.md,
                    ),
                    SizedBox(height: JivoSpacing.sm),
                    SkeletonBox(height: 12, width: double.infinity),
                    SizedBox(height: JivoSpacing.xs),
                    SkeletonBox(height: 12, width: 64),
                    SizedBox(height: JivoSpacing.md),
                    SkeletonBox(height: 18, width: 72),
                    SizedBox(height: JivoSpacing.md),
                    SkeletonBox(
                      height: 48,
                      width: double.infinity,
                      radius: JivoRadii.md,
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ],
    ),
  );
}
