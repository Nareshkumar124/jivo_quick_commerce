import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:jivo_core/jivo_core.dart';

import '../html/safe_html.dart';

/// Renders [parseSafeHtml] blocks as text: headings (announced as headers),
/// paragraphs, list items and quotes, with bold, italic and tappable safe
/// links. Text scales with the system font size.
class SafeHtmlView extends StatefulWidget {
  const SafeHtmlView({required this.blocks, required this.onLink, super.key});

  final List<HtmlBlock> blocks;

  /// A tapped link (already checked with [isSafeHtmlLink]).
  final ValueChanged<Uri> onLink;

  @override
  State<SafeHtmlView> createState() => _SafeHtmlViewState();
}

class _SafeHtmlViewState extends State<SafeHtmlView> {
  final List<TapGestureRecognizer> _recognizers = [];

  void _disposeRecognizers() {
    for (final recognizer in _recognizers) {
      recognizer.dispose();
    }
    _recognizers.clear();
  }

  @override
  void dispose() {
    _disposeRecognizers();
    super.dispose();
  }

  TextSpan _span(HtmlSpan span, TextStyle? base, Color linkColor) {
    final link = span.link;
    TapGestureRecognizer? recognizer;
    if (link != null) {
      recognizer = TapGestureRecognizer()..onTap = () => widget.onLink(link);
      _recognizers.add(recognizer);
    }
    return TextSpan(
      text: span.text,
      recognizer: recognizer,
      style: TextStyle(
        fontWeight: span.bold ? FontWeight.w700 : null,
        fontStyle: span.italic ? FontStyle.italic : null,
        color: link == null ? null : linkColor,
        decoration: link == null ? null : TextDecoration.underline,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    _disposeRecognizers();
    final theme = Theme.of(context);
    final text = theme.textTheme;
    final linkColor = theme.colorScheme.primary;

    Widget block(HtmlBlock block) {
      final style = switch (block.kind) {
        HtmlBlockKind.heading1 => text.headlineSmall?.copyWith(
          fontWeight: FontWeight.w700,
        ),
        HtmlBlockKind.heading2 => text.titleLarge,
        HtmlBlockKind.heading3 => text.titleMedium,
        HtmlBlockKind.quote => text.bodyLarge?.copyWith(
          fontStyle: FontStyle.italic,
        ),
        _ => text.bodyLarge,
      };
      final rich = Text.rich(
        TextSpan(
          style: style,
          children: [
            for (final span in block.spans) _span(span, style, linkColor),
          ],
        ),
      );
      final heading =
          block.kind == HtmlBlockKind.heading1 ||
          block.kind == HtmlBlockKind.heading2 ||
          block.kind == HtmlBlockKind.heading3;
      final Widget child = switch (block.kind) {
        HtmlBlockKind.listItem => Padding(
          padding: EdgeInsets.only(left: JivoSpacing.lg * block.depth),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: JivoSpacing.xl,
                child: Text(block.marker ?? '•', style: style),
              ),
              Expanded(child: rich),
            ],
          ),
        ),
        HtmlBlockKind.quote => Container(
          padding: const EdgeInsets.only(left: JivoSpacing.md),
          decoration: BoxDecoration(
            border: Border(
              left: BorderSide(color: theme.colorScheme.outline, width: 3),
            ),
          ),
          child: rich,
        ),
        _ => heading ? Semantics(header: true, child: rich) : rich,
      };
      return Padding(
        padding: EdgeInsets.only(
          top: heading ? JivoSpacing.md : 0,
          bottom: block.kind == HtmlBlockKind.listItem
              ? JivoSpacing.xs
              : JivoSpacing.md,
        ),
        child: child,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [for (final b in widget.blocks) block(b)],
    );
  }
}
