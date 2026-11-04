import 'package:flutter/foundation.dart';

/// A small, safe reader for server HTML (CMS pages, `06 §2.7`).
///
/// The HTML is never handed to a web view or an HTML engine. It is reduced
/// to plain text blocks with a fixed set of styles:
///
/// - blocks: `h1`–`h6` (three heading sizes), `p`, `div`, `li` in `ul`/`ol`,
///   `blockquote`, `br`;
/// - inline: `strong`/`b`, `em`/`i`, `a href` (only `https:`, `mailto:`,
///   `tel:` and `jivo:` links; any other link is plain text);
/// - everything else is dropped: the content of `script`, `style`,
///   `iframe`, `object`, `embed`, `svg`, `template`, forms and comments is
///   removed entirely; other tags keep their text but lose all attributes
///   (so no inline handlers, styles or images).

enum HtmlBlockKind { heading1, heading2, heading3, paragraph, listItem, quote }

@immutable
class HtmlSpan {
  const HtmlSpan(this.text, {this.bold = false, this.italic = false, this.link});

  final String text;
  final bool bold;
  final bool italic;

  /// A safe link target ([isSafeHtmlLink]), or null.
  final Uri? link;

  @override
  bool operator ==(Object other) =>
      other is HtmlSpan &&
      other.text == text &&
      other.bold == bold &&
      other.italic == italic &&
      other.link == link;

  @override
  int get hashCode => Object.hash(text, bold, italic, link);

  @override
  String toString() =>
      'HtmlSpan($text${bold ? ', bold' : ''}${italic ? ', italic' : ''}'
      '${link == null ? '' : ', $link'})';
}

@immutable
class HtmlBlock {
  const HtmlBlock(this.kind, this.spans, {this.marker, this.depth = 0});

  final HtmlBlockKind kind;
  final List<HtmlSpan> spans;

  /// `•` or `1.` for list items.
  final String? marker;

  /// List nesting, 0 for top-level items.
  final int depth;

  String get text => spans.map((s) => s.text).join();
}

/// Links a CMS page may open.
bool isSafeHtmlLink(Uri uri) => switch (uri.scheme) {
  'https' => uri.host.isNotEmpty,
  'mailto' || 'tel' => uri.path.isNotEmpty,
  'jivo' => true,
  _ => false,
};

/// The most HTML read (a CMS page is a few KB).
const _maxInput = 200000;

const _droppedWithContent =
    'script|style|iframe|object|embed|noscript|template|svg|math|head|'
    'title|textarea|select|button|form|canvas|audio|video';

final _comments = RegExp(r'<!--[\s\S]*?(-->|$)');
final _declarations = RegExp(r'<[!?][^>]*>');
final _dropped = RegExp(
  '<($_droppedWithContent)\\b[^>]*>[\\s\\S]*?</\\1\\s*>',
  caseSensitive: false,
);
final _droppedUnclosed = RegExp(
  '<($_droppedWithContent)\\b[\\s\\S]*\$',
  caseSensitive: false,
);
final _tokens = RegExp(
  r'<\s*(/?)\s*([a-zA-Z][a-zA-Z0-9]*)((?:[^>"' "'" r']|"[^"]*"|' "'[^']*')*)>"
  r'|([^<]+)|(<)',
);
final _href = RegExp(
  r'''\bhref\s*=\s*(?:"([^"]*)"|'([^']*)'|([^\s"'>]+))''',
  caseSensitive: false,
);
final _whitespace = RegExp(r'\s+');

/// Parses [html] into safe text blocks; see the library comment.
List<HtmlBlock> parseSafeHtml(String html) {
  var source = html.length > _maxInput ? html.substring(0, _maxInput) : html;
  source = source.replaceAll(_comments, ' ').replaceAll(_declarations, ' ');
  // Repeat: a dropped element may hide inside another one's attributes.
  String previous;
  do {
    previous = source;
    source = source.replaceAll(_dropped, ' ');
  } while (source != previous);
  source = source.replaceAll(_droppedUnclosed, ' ');

  final builder = _Builder();
  for (final match in _tokens.allMatches(source)) {
    final text = match.group(4) ?? match.group(5);
    if (text != null) {
      builder.text(decodeHtmlEntities(text));
      continue;
    }
    final closing = match.group(1) == '/';
    final tag = match.group(2)!.toLowerCase();
    builder.tag(tag, closing: closing, attributes: match.group(3) ?? '');
  }
  builder.flush();
  return builder.blocks;
}

class _List {
  _List({required this.ordered});

  final bool ordered;
  int count = 0;
}

class _Builder {
  final List<HtmlBlock> blocks = [];
  final List<HtmlSpan> _spans = [];
  final List<_List> _lists = [];
  final List<Uri?> _links = [];
  HtmlBlockKind _kind = HtmlBlockKind.paragraph;
  String? _marker;
  int _depth = 0;
  int _bold = 0;
  int _italic = 0;

  void text(String raw) {
    var value = raw.replaceAll(_whitespace, ' ');
    final last = _spans.isEmpty ? null : _spans.last.text;
    if (last == null || last.endsWith(' ') || last.endsWith('\n')) {
      value = value.trimLeft();
    }
    if (value.isEmpty) return;
    _spans.add(
      HtmlSpan(
        value,
        bold: _bold > 0,
        italic: _italic > 0,
        link: _links.isEmpty ? null : _links.last,
      ),
    );
  }

  void flush() {
    // Merge neighbours with the same style, then trim the ends.
    final merged = <HtmlSpan>[];
    for (final span in _spans) {
      final last = merged.isEmpty ? null : merged.last;
      if (last != null &&
          last.bold == span.bold &&
          last.italic == span.italic &&
          last.link == span.link) {
        merged[merged.length - 1] = HtmlSpan(
          last.text + span.text,
          bold: span.bold,
          italic: span.italic,
          link: span.link,
        );
      } else {
        merged.add(span);
      }
    }
    _spans.clear();
    while (merged.isNotEmpty && merged.last.text.trim().isEmpty) {
      merged.removeLast();
    }
    if (merged.isNotEmpty) {
      final last = merged.last;
      merged[merged.length - 1] = HtmlSpan(
        last.text.trimRight(),
        bold: last.bold,
        italic: last.italic,
        link: last.link,
      );
      blocks.add(
        HtmlBlock(_kind, List.unmodifiable(merged), marker: _marker, depth: _depth),
      );
    }
    _kind = HtmlBlockKind.paragraph;
    _marker = null;
    _depth = 0;
  }

  void _startBlock(HtmlBlockKind kind, {String? marker, int depth = 0}) {
    flush();
    _kind = kind;
    _marker = marker;
    _depth = depth;
  }

  void tag(String tag, {required bool closing, required String attributes}) {
    switch (tag) {
      case 'h1':
      case 'h2':
      case 'h3':
      case 'h4':
      case 'h5':
      case 'h6':
        if (closing) {
          flush();
        } else {
          _startBlock(switch (tag) {
            'h1' => HtmlBlockKind.heading1,
            'h2' => HtmlBlockKind.heading2,
            _ => HtmlBlockKind.heading3,
          });
        }
      case 'p' ||
          'div' ||
          'section' ||
          'article' ||
          'header' ||
          'footer' ||
          'tr' ||
          'table' ||
          'hr':
        flush();
      case 'blockquote':
        closing ? flush() : _startBlock(HtmlBlockKind.quote);
      case 'ul' || 'ol':
        flush();
        if (closing) {
          if (_lists.isNotEmpty) _lists.removeLast();
        } else if (_lists.length < 8) {
          _lists.add(_List(ordered: tag == 'ol'));
        }
      case 'li':
        if (closing) {
          flush();
        } else {
          final list = _lists.isEmpty ? null : _lists.last;
          final marker = list != null && list.ordered
              ? '${++list.count}.'
              : '•';
          _startBlock(
            HtmlBlockKind.listItem,
            marker: marker,
            depth: _lists.isEmpty ? 0 : _lists.length - 1,
          );
        }
      case 'br':
        if (_spans.isNotEmpty) {
          _spans.add(
            HtmlSpan('\n', bold: _bold > 0, italic: _italic > 0),
          );
        }
      case 'strong' || 'b':
        _bold = closing ? (_bold - 1).clamp(0, 99) : _bold + 1;
      case 'em' || 'i':
        _italic = closing ? (_italic - 1).clamp(0, 99) : _italic + 1;
      case 'a':
        if (closing) {
          if (_links.isNotEmpty) _links.removeLast();
        } else {
          _links.add(_safeHref(attributes));
        }
      default:
      // Any other tag: ignored, its text is kept.
    }
  }

  static Uri? _safeHref(String attributes) {
    final match = _href.firstMatch(attributes);
    if (match == null) return null;
    final raw = decodeHtmlEntities(
      match.group(1) ?? match.group(2) ?? match.group(3) ?? '',
    ).trim();
    // Control characters and spaces inside a scheme are a classic way to
    // sneak `java\tscript:` past a check.
    if (raw.isEmpty || RegExp(r'[\x00-\x20]').hasMatch(raw)) return null;
    final uri = Uri.tryParse(raw);
    if (uri == null) return null;
    return isSafeHtmlLink(uri) ? uri : null;
  }
}

const _named = {
  'amp': '&',
  'lt': '<',
  'gt': '>',
  'quot': '"',
  'apos': "'",
  'nbsp': ' ',
  'ndash': '–',
  'mdash': '—',
  'hellip': '…',
  'rsquo': '’',
  'lsquo': '‘',
  'rdquo': '”',
  'ldquo': '“',
  'copy': '©',
  'reg': '®',
  'trade': '™',
  'bull': '•',
  'rupee': '₹',
};

final _entity = RegExp(r'&(#[0-9]{1,7}|#[xX][0-9a-fA-F]{1,6}|[a-zA-Z]+);');

/// Decodes named and numeric character references; unknown ones stay.
String decodeHtmlEntities(String text) => text.replaceAllMapped(_entity, (m) {
  final name = m.group(1)!;
  if (name.startsWith('#')) {
    final hex = name.length > 1 && (name[1] == 'x' || name[1] == 'X');
    final code = int.tryParse(
      hex ? name.substring(2) : name.substring(1),
      radix: hex ? 16 : 10,
    );
    if (code == null ||
        code <= 0 ||
        code > 0x10FFFF ||
        (code >= 0xD800 && code <= 0xDFFF)) {
      return '�';
    }
    return String.fromCharCode(code);
  }
  return _named[name.toLowerCase()] ?? m.group(0)!;
});
