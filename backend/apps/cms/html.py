"""Server-side HTML allow-list for CMS pages (09 §3.6: no stored XSS in content the apps render).

`sanitize_html()` keeps only headings, paragraphs, line breaks, lists, blockquotes, strong/em
(and their b/i spellings) and links whose `href` is `https:`, `mailto:` or `tel:`. Everything
else is removed: scripts and styles with their content, every other tag (its text is kept), every
other attribute (`style`, `class`, `on*` handlers, `target`, ...), comments, relative and other
scheme links (the `<a>` stays, without `href`).

Built on nh3 (the Rust `ammonia` sanitiser). The apps still parse the HTML defensively
(`parseSafeHtml` in the customer app); this is the server half of that defence.
"""

import nh3

ALLOWED_TAGS = frozenset(
    {
        "h1",
        "h2",
        "h3",
        "h4",
        "h5",
        "h6",
        "p",
        "br",
        "ul",
        "ol",
        "li",
        "blockquote",
        "strong",
        "em",
        "b",
        "i",
        "a",
    }
)
ALLOWED_ATTRIBUTES = {"a": {"href"}}
ALLOWED_LINK_PREFIXES = ("https://", "mailto:", "tel:")
# Removed with everything inside them (other unknown tags keep their text).
DROPPED_WITH_CONTENT = frozenset({"script", "style", "iframe", "object", "embed", "template"})


def _href_filter(element: str, attribute: str, value: str) -> str | None:
    """Keep an `href` only with an allowed scheme; relative links are dropped too."""
    if element == "a" and attribute == "href":
        return value if value.strip().lower().startswith(ALLOWED_LINK_PREFIXES) else None
    return value


def sanitize_html(html: str) -> str:
    return nh3.clean(
        html or "",
        tags=set(ALLOWED_TAGS),
        clean_content_tags=set(DROPPED_WITH_CONTENT),
        attributes={tag: set(attrs) for tag, attrs in ALLOWED_ATTRIBUTES.items()},
        attribute_filter=_href_filter,
        url_schemes={"https", "mailto", "tel"},
        link_rel=None,
        strip_comments=True,
    ).strip()
