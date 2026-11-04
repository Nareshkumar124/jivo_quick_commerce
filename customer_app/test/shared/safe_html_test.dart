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
}
