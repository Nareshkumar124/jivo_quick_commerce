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
///   `iframe`, `object`, `embed`, `svg`, `math`, `template`, forms and
///   comments is removed entirely; other tags keep their text but lose all
///   attributes (so no inline handlers, styles or images).
///
/// The reader is a single-pass, hand-written tokenizer: every character is
/// looked at a bounded number of times, so hostile input (thousands of
/// unclosed `<script>` or `<a "` openers) costs linear time. A tag that is
/// never closed (no `>`, an unterminated quote, a raw-text element without
/// its end tag) swallows the rest of the input, as in a browser. Input,
/// block count, nesting depth and link count are capped.

enum HtmlBlockKind { heading1, heading2, heading3, paragraph, listItem, quote }

@immutable
class HtmlSpan {
  const HtmlSpan(
    this.text, {
    this.bold = false,
    this.italic = false,
    this.link,
  });

  final String text;
  final bool bold;
  final bool italic;

  /// A safe link target ([isSafeHtmlLink]), or null.
  final Uri? link;

  bool sameStyle(HtmlSpan other) =>
      other.bold == bold && other.italic == italic && other.link == link;

  @override
  bool operator ==(Object other) =>
      other is HtmlSpan && other.text == text && sameStyle(other);

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

/// The most HTML read, in UTF-16 code units (a CMS page is a few KB).
const safeHtmlMaxInput = 50000;

/// The most blocks produced; the rest of the page is dropped.
const safeHtmlMaxBlocks = 1000;

/// The deepest inline (`b`/`i`/`a`) and list nesting honoured; deeper
/// tags keep their text without more styling.
const safeHtmlMaxDepth = 16;

/// The most links kept; later links are plain text.
const safeHtmlMaxLinks = 200;

/// Elements dropped together with everything inside them.
const _rawText = {
  'script',
  'style',
  'iframe',
  'object',
  'embed',
  'noscript',
  'template',
  'svg',
  'math',
  'head',
  'title',
  'textarea',
  'select',
  'button',
  'form',
  'canvas',
  'audio',
  'video',
  'xmp',
  'plaintext',
  'noembed',
  'noframes',
};

/// Parses [html] into safe text blocks; see the library comment.
List<HtmlBlock> parseSafeHtml(String html) {
  final source = html.length > safeHtmlMaxInput
      ? html.substring(0, safeHtmlMaxInput)
      : html;
  final builder = _Builder();
  _Tokenizer(source, builder).run();
  builder.flush();
  return builder.blocks;
}

bool _isAsciiLetter(int c) =>
    (c >= 0x41 && c <= 0x5A) || (c >= 0x61 && c <= 0x7A);

bool _isAsciiAlnum(int c) => _isAsciiLetter(c) || (c >= 0x30 && c <= 0x39);

bool _isSpace(int c) =>
    c == 0x20 || c == 0x09 || c == 0x0A || c == 0x0C || c == 0x0D;

const _gt = 0x3E; // >
const _slash = 0x2F; // /
const _bang = 0x21; // !
const _question = 0x3F; // ?
const _equals = 0x3D; // =
const _dquote = 0x22; // "
const _squote = 0x27; // '

/// One left-to-right pass. `_pos` only moves forward; every search
/// (`indexOf`) starts at `_pos` and the position jumps past what it found,
/// or parsing stops when it found nothing.
class _Tokenizer {
  _Tokenizer(this.s, this.out) : _lower = s.toLowerCase();

  final String s;
  final String _lower;
  final _Builder out;
  int _pos = 0;

  void run() {
    final length = s.length;
    while (_pos < length && !out.full) {
      final lt = s.indexOf('<', _pos);
      if (lt < 0) {
        out.text(s.substring(_pos));
        return;
      }
      if (lt > _pos) out.text(s.substring(_pos, lt));
      _pos = lt;
      if (!_markup()) return;
    }
  }

  /// At a `<`. Returns false when the rest of the input is swallowed.
  bool _markup() {
    final length = s.length;
    final next = _pos + 1 < length ? s.codeUnitAt(_pos + 1) : -1;

    // Comment: to `-->`, or to the end.
    if (s.startsWith('<!--', _pos)) {
      final end = s.indexOf('-->', _pos + 4);
      if (end < 0) return false;
      _pos = end + 3;
      return true;
    }
    // `<!doctype>`, `<?xml?>`, `</ >`: skipped to the next `>`.
    if (next == _bang ||
        next == _question ||
        (next == _slash &&
            !(_pos + 2 < length && _isAsciiLetter(s.codeUnitAt(_pos + 2))))) {
      final end = s.indexOf('>', _pos + 1);
      if (end < 0) return false;
      _pos = end + 1;
      return true;
    }

    final closing = next == _slash;
    var i = _pos + (closing ? 2 : 1);
    if (i >= length || !_isAsciiLetter(s.codeUnitAt(i))) {
      // A lone `<` is text.
      out.text('<');
      _pos += 1;
      return true;
    }
    final nameStart = i;
    while (i < length && _isAsciiAlnum(s.codeUnitAt(i))) {
      i++;
    }
    final name = _lower.substring(nameStart, i);

    // Attributes to the closing `>`, skipping quoted values.
    final attrStart = i;
    while (true) {
      if (i >= length) return false; // Unclosed tag: swallow the rest.
      final c = s.codeUnitAt(i);
      if (c == _gt) break;
      if (c == _dquote || c == _squote) {
        final end = s.indexOf(String.fromCharCode(c), i + 1);
        if (end < 0) return false; // Unterminated quote.
        i = end + 1;
      } else {
        i++;
      }
    }
    final attributes = s.substring(attrStart, i);
    _pos = i + 1;

    if (!closing && _rawText.contains(name)) {
      // Drop everything up to the matching end tag (or the end).
      final end = _lower.indexOf('</$name', _pos);
      if (end < 0) return false;
      final gt = s.indexOf('>', end);
      if (gt < 0) return false;
      _pos = gt + 1;
      return true;
    }
    out.tag(name, closing: closing, attributes: attributes);
    return true;
  }
}

class _List {
  _List({required this.ordered});

  final bool ordered;
  int count = 0;
}

final _whitespace = RegExp(r'\s+');

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
  int _linkCount = 0;

  /// Stops the tokenizer once the block cap is reached.
  bool get full => blocks.length >= safeHtmlMaxBlocks;

  bool _endsWithSpace() {
    if (_spans.isEmpty) return true;
    final last = _spans.last.text;
    return last.endsWith(' ') || last.endsWith('\n');
  }

  void text(String raw) {
    var value = decodeHtmlEntities(raw).replaceAll(_whitespace, ' ');
    if (_endsWithSpace()) value = value.trimLeft();
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
    // Merge runs of the same style with a buffer (linear, no repeated
    // string concatenation), then trim the end.
    final merged = <HtmlSpan>[];
    var i = 0;
    while (i < _spans.length) {
      final first = _spans[i];
      final buffer = StringBuffer(first.text);
      var j = i + 1;
      while (j < _spans.length && _spans[j].sameStyle(first)) {
        buffer.write(_spans[j].text);
        j++;
      }
      merged.add(
        HtmlSpan(
          buffer.toString(),
          bold: first.bold,
          italic: first.italic,
          link: first.link,
        ),
      );
      i = j;
    }
    _spans.clear();
    while (merged.isNotEmpty && merged.last.text.trim().isEmpty) {
      merged.removeLast();
    }
    if (merged.isNotEmpty && !full) {
      final last = merged.last;
      merged[merged.length - 1] = HtmlSpan(
        last.text.trimRight(),
        bold: last.bold,
        italic: last.italic,
        link: last.link,
      );
      blocks.add(
        HtmlBlock(
          _kind,
          List.unmodifiable(merged),
          marker: _marker,
          depth: _depth,
        ),
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

  static int _open(int depth) => depth < safeHtmlMaxDepth ? depth + 1 : depth;

  static int _close(int depth) => depth > 0 ? depth - 1 : 0;

  void tag(String tag, {required bool closing, required String attributes}) {
    switch (tag) {
      case 'h1' || 'h2' || 'h3' || 'h4' || 'h5' || 'h6':
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
        } else if (_lists.length < safeHtmlMaxDepth) {
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
          _spans.add(HtmlSpan('\n', bold: _bold > 0, italic: _italic > 0));
        }
      case 'strong' || 'b':
        _bold = closing ? _close(_bold) : _open(_bold);
      case 'em' || 'i':
        _italic = closing ? _close(_italic) : _open(_italic);
      case 'a':
        if (closing) {
          if (_links.isNotEmpty) _links.removeLast();
        } else if (_links.length < safeHtmlMaxDepth) {
          Uri? link;
          if (_linkCount < safeHtmlMaxLinks) {
            link = _safeHref(attributes);
            if (link != null) _linkCount++;
          }
          _links.add(link);
        }
      default:
      // Any other tag: ignored, its text is kept.
    }
  }

  static Uri? _safeHref(String attributes) {
    final raw = hrefOf(attributes);
    if (raw == null) return null;
    final value = decodeHtmlEntities(raw).trim();
    // Control characters and spaces inside a scheme are a classic way to
    // sneak `java\tscript:` past a check.
    if (value.isEmpty || RegExp(r'[\x00-\x20]').hasMatch(value)) return null;
    final uri = Uri.tryParse(value);
    if (uri == null) return null;
    return isSafeHtmlLink(uri) ? uri : null;
  }
}

/// The raw `href` value in a tag's attribute text (`href="x"`, `href='x'`,
/// `HREF=x`), or null. A hand-written linear scan.
@visibleForTesting
String? hrefOf(String attributes) {
  final a = attributes;
  final length = a.length;
  var i = 0;
  while (i < length) {
    // Skip separators.
    while (i < length &&
        (_isSpace(a.codeUnitAt(i)) || a.codeUnitAt(i) == _slash)) {
      i++;
    }
    if (i >= length) break;
    // The attribute name.
    final nameStart = i;
    while (i < length) {
      final c = a.codeUnitAt(i);
      if (_isSpace(c) || c == _equals || c == _slash || c == _gt) break;
      if (c == _dquote || c == _squote) break;
      i++;
    }
    if (i == nameStart) {
      i++; // A stray quote or `=`: skip it.
      continue;
    }
    final name = a.substring(nameStart, i).toLowerCase();
    while (i < length && _isSpace(a.codeUnitAt(i))) {
      i++;
    }
    if (i >= length || a.codeUnitAt(i) != _equals) continue; // No value.
    i++;
    while (i < length && _isSpace(a.codeUnitAt(i))) {
      i++;
    }
    String value;
    if (i < length &&
        (a.codeUnitAt(i) == _dquote || a.codeUnitAt(i) == _squote)) {
      final quote = a[i];
      final end = a.indexOf(quote, i + 1);
      // The tokenizer only passes tags whose quotes are closed.
      if (end < 0) return null;
      value = a.substring(i + 1, end);
      i = end + 1;
    } else {
      final start = i;
      while (i < length && !_isSpace(a.codeUnitAt(i))) {
        i++;
      }
      value = a.substring(start, i);
    }
    if (name == 'href') return value;
  }
  return null;
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
  'tab': '\t',
  'newline': '\n',
  'colon': ':',
};

/// Bounded alternatives: each `&` looks at most 33 characters ahead.
final _entity = RegExp(
  r'&(#[0-9]{1,7}|#[xX][0-9a-fA-F]{1,6}|[a-zA-Z][a-zA-Z0-9]{0,31});',
);

/// Decodes named and numeric character references; unknown ones stay.
String decodeHtmlEntities(String text) {
  if (!text.contains('&')) return text;
  return text.replaceAllMapped(_entity, (m) {
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
}
