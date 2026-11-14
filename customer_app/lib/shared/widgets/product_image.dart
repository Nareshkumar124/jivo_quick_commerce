import 'package:flutter/material.dart';
import 'package:jivo_core/jivo_core.dart';

import '../../app/theme.dart';

/// Every product, category and banner image goes through this widget, so
/// switching to `cached_network_image` touches one file. Without a URL (placeholder data) or on a load error it shows a
/// neutral placeholder. Decorative: callers provide the semantics.
class ProductImage extends StatelessWidget {
  const ProductImage({
    required this.url,
    this.fit = BoxFit.contain,
    this.icon = Icons.shopping_basket_outlined,
    this.onWell = false,
    super.key,
  });

  final String? url;
  final BoxFit fit;

  /// Shown in the placeholder.
  final IconData icon;

  /// The image sits on the tinted image well: multiply the well colour in so
  /// the white photo background takes the well colour (bottle looks cut out).
  final bool onWell;

  @override
  Widget build(BuildContext context) {
    final placeholder = _Placeholder(icon: icon);
    final source = url;
    if (source == null || source.isEmpty) return placeholder;
    // Planned performance work: cached_network_image (disk cache across launches); the
    // catalog API serves image URLs since Phase 2.
    final image = Image.network(
      source,
      fit: fit,
      excludeFromSemantics: true,
      errorBuilder: (_, _, _) => placeholder,
      loadingBuilder: (context, child, progress) =>
          progress == null ? child : placeholder,
    );
    if (!onWell) return image;
    return ColorFiltered(
      colorFilter: ColorFilter.mode(
        context.customerColors.imageWell,
        BlendMode.multiply,
      ),
      child: image,
    );
  }
}

class _Placeholder extends StatelessWidget {
  const _Placeholder({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ExcludeSemantics(
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(JivoRadii.sm),
        ),
        child: Center(
          child: Icon(icon, size: 32, color: scheme.onSurfaceVariant),
        ),
      ),
    );
  }
}
