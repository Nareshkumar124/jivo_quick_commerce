import 'package:flutter/material.dart';
import 'package:jivo_core/jivo_core.dart';

/// Every product, category and banner image goes through this widget, so
/// switching to `cached_network_image` touches one file. Without a URL (placeholder data) or on a load error it shows a
/// neutral placeholder. Decorative: callers provide the semantics.
class ProductImage extends StatelessWidget {
  const ProductImage({
    required this.url,
    this.fit = BoxFit.contain,
    this.icon = Icons.shopping_basket_outlined,
    super.key,
  });

  final String? url;
  final BoxFit fit;

  /// Shown in the placeholder.
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final placeholder = _Placeholder(icon: icon);
    final source = url;
    if (source == null || source.isEmpty) return placeholder;
    // TODO(perf): cached_network_image (disk cache across launches); the
    // catalog API serves image URLs since Phase 2.
    return Image.network(
      source,
      fit: fit,
      excludeFromSemantics: true,
      errorBuilder: (_, _, _) => placeholder,
      loadingBuilder: (context, child, progress) =>
          progress == null ? child : placeholder,
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
