import 'package:customer_app/shared/html/safe_html.dart';
import 'package:flutter_test/flutter_test.dart';

/// The CMS HTML reader must never let markup run or smuggle links.
void main() {
  String plain(String html) =>
      parseSafeHtml(html).map((b) => b.text).join('|');

  List<Uri?> links(String html) => [
    for (final block in parseSafeHtml(html))
      for (final span in block.spans) span.link,
  ];

  test('headings, paragraphs and lists become blocks', () {
    final blocks = parseSafeHtml(
      '<h1>Title</h1><p>One <b>bold</b> and <em>soft</em>.</p>'
      '<h3>Sub</h3><ol><li>First</li><li>Second</li></ol>'
      '<ul><li>Dot</li></ul><blockquote>Quote</blockquote>',
    );
    expect(blocks.map((b) => b.kind), [
      HtmlBlockKind.heading1,
      HtmlBlockKind.paragraph,
      HtmlBlockKind.heading3,
      HtmlBlockKind.listItem,
      HtmlBlockKind.listItem,
      HtmlBlockKind.listItem,
      HtmlBlockKind.quote,
    ]);
    expect(blocks[1].spans, const [
      HtmlSpan('One '),
      HtmlSpan('bold', bold: true),
      HtmlSpan(' and '),
      HtmlSpan('soft', italic: true),
      HtmlSpan('.'),
    ]);
    expect(blocks[3].marker, '1.');
    expect(blocks[4].marker, '2.');
    expect(blocks[5].marker, '•');
  });

  test('script, style, iframe and comments are removed with content', () {
    expect(
      plain(
        '<p>a</p><script>alert(1)</script><style>p{}</style>'
        '<iframe src="https://x.y">frame</iframe><!-- secret -->'
        '<SCRIPT type="x">evil()</SCRIPT ><p>b</p>',
      ),
      'a|b',
    );
  });

  test('an unclosed script drops everything after it', () {
    expect(plain('<p>safe</p><script>alert(1)<p>more</p>'), 'safe');
  });

  test('nested tricks do not leave a script behind', () {
    final text = plain('<scr<script>x</script>ipt>alert(1)</script>');
    expect(text.contains('<script'), isFalse);
  });

  test('attributes never survive: handlers, styles, images', () {
    final blocks = parseSafeHtml(
      '<p onclick="steal()" style="color:red">Hi<img src=x onerror=steal()>'
      '</p>',
    );
    expect(blocks.single.text, 'Hi');
  });

  test('only https, mailto, tel and jivo links are kept', () {
    expect(
      links(
        '<p><a href="https://jivo.in/t">a</a> '
        '<a href="mailto:care@jivo.in">b</a> '
        '<a href="tel:+911800">c</a> '
        "<a href='jivo://orders'>d</a></p>",
      ).whereType<Uri>().map((u) => u.scheme),
      ['https', 'mailto', 'tel', 'jivo'],
    );
    for (final bad in [
      'javascript:alert(1)',
      'JaVaScRiPt:alert(1)',
      'java\tscript:alert(1)',
      'java&#x09;script:alert(1)',
      '&#106;avascript:alert(1)',
      'data:text/html,<b>x</b>',
      'http://jivo.in',
      'https://',
      'file:///etc/passwd',
      'intent://x#Intent;end',
      '//evil.example',
      'vbscript:x',
    ]) {
      expect(
        links('<p><a href="$bad">x</a></p>').whereType<Uri>(),
        isEmpty,
        reason: bad,
      );
    }
  });

  test('a link keeps its text when its target is refused', () {
    expect(plain('<p><a href="javascript:x()">Read</a> me</p>'), 'Read me');
  });

  test('entities are decoded; markup in text stays text', () {
    expect(
      plain('<p>A &amp; B &lt;script&gt; &#8377;5 &#x20B9;6 &bogus;</p>'),
      'A & B <script> ₹5 ₹6 &bogus;',
    );
    expect(decodeHtmlEntities('&#0;&#xD800;'), '��');
  });

  test('whitespace collapses; empty blocks are dropped; br breaks', () {
    final blocks = parseSafeHtml('<p>  a \n\n b </p><p> </p><p>x<br>y</p>');
    expect(blocks.map((b) => b.text), ['a b', 'x\ny']);
  });

  test('plain text without tags is one paragraph', () {
    expect(plain('Just text'), 'Just text');
    expect(parseSafeHtml(''), isEmpty);
  });

  group('more sanitiser cases (code review of 2e2560a)', () {
    test('svg and math are dropped with their links', () {
      final html =
          '<p>a</p><svg><a href="javascript:alert(1)">x</a>'
          '<a xlink:href="https://evil.example">y</a></svg>'
          '<math><a href="javascript:alert(2)">z</a></math><p>b</p>';
      expect(plain(html), 'a|b');
      expect(links(html).whereType<Uri>(), isEmpty);
    });

    test('uppercase tags and attributes work', () {
      final html = '<P><A HREF="https://jivo.in/a">Up</A></P><H2>Two</H2>';
      expect(links(html).whereType<Uri>().single.path, '/a');
      expect(parseSafeHtml(html).last.kind, HtmlBlockKind.heading2);
    });

    test('unquoted href is read; other attributes are ignored', () {
      expect(hrefOf(' href=https://jivo.in/x class=y'), 'https://jivo.in/x');
      expect(hrefOf(" title='href=no' HREF = \"tel:1\""), 'tel:1');
      expect(hrefOf(' data-href="https://x.y"'), isNull);
      expect(hrefOf(' href'), isNull);
      expect(
        links('<p><a href=https://jivo.in/u>u</a></p>').whereType<Uri>().single,
        Uri.parse('https://jivo.in/u'),
      );
    });

    test('entity-encoded schemes stay refused', () {
      for (final bad in [
        'javascript&colon;alert(1)',
        'java&Tab;script:alert(1)',
        'java&NewLine;script:alert(1)',
      ]) {
        expect(
          links('<p><a href="$bad">x</a></p>').whereType<Uri>(),
          isEmpty,
          reason: bad,
        );
      }
    });

    test('malformed or unclosed tags swallow the rest, never run', () {
      expect(plain('<p>ok</p><a href="x'), 'ok');
      expect(plain('<p>ok</p><a href=x'), 'ok');
      expect(plain('<<<'), '<<<');
      expect(plain('a < b and c<1'), 'a < b and c<1');
      expect(plain('<p>x</p></ >y'), 'x|y');
      expect(plain('<p>x</p><!-- never closed <p>secret</p>'), 'x');
    });

    test('deep nesting is capped but keeps the text', () {
      final html = '${'<b>' * 10000}deep${'</b>' * 10000}';
      final blocks = parseSafeHtml(html);
      expect(blocks.single.text, 'deep');
      expect(blocks.single.spans.single.bold, isTrue);
      final lists = '${'<ul><li>x' * 100}${'</li></ul>' * 100}';
      expect(
        parseSafeHtml(lists).map((b) => b.depth).reduce((a, b) => a > b ? a : b),
        lessThan(safeHtmlMaxDepth),
      );
    });

    test('long input is cut at the cap; blocks and links are capped', () {
      final long = '<p>${'a' * (safeHtmlMaxInput * 2)}</p>';
      expect(
        parseSafeHtml(long).single.text.length,
        lessThanOrEqualTo(safeHtmlMaxInput),
      );
      expect(
        parseSafeHtml('<p>x</p>' * 5000).length,
        lessThanOrEqualTo(safeHtmlMaxBlocks),
      );
      final many = '<a href="https://jivo.in/l">l</a> ' * 1000;
      expect(
        links(many).whereType<Uri>().length,
        lessThanOrEqualTo(safeHtmlMaxLinks),
      );
    });
  });

  group('linear time on hostile input (budget 200 ms each)', () {
    void fast(String name, String html) {
      test(name, () {
        parseSafeHtml('<p>warm-up</p>');
        final watch = Stopwatch()..start();
        parseSafeHtml(html);
        watch.stop();
        expect(
          watch.elapsedMilliseconds,
          lessThan(200),
          reason: '$name took ${watch.elapsedMilliseconds} ms',
        );
      });
    }

    fast('unclosed <script> x5000', '<script>' * 5000);
    fast('unclosed <script x5000 (no >)', '<script ' * 5000);
    fast('<a " x10000', '<a "' * 10000);
    fast("<a href=' x5000", "<a href='" * 5000);
    fast('lone < x50000', '<' * 50000);
    fast('<<< x16000 with text', '<<<a' * 12000);
    fast('</ x20000', '</' * 20000);
    fast('<!-- x10000', '<!--' * 10000);
    fast('nested <b> x10000', '${'<b>' * 10000}x${'</b>' * 10000}');
    fast('<p> x10000', '<p>x' * 10000);
    fast('& entities x10000', '&aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa' * 1000);
    fast(
      'many same-style spans in one block',
      '${'x<span>' * 8000}</p>',
    );
  });
}
