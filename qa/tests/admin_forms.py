"""Read a Django admin / console HTML form the way a browser would (every input, select,
textarea with its current value, including inline management forms), so QA can post it back
with only the fields it means to change. No field is guessed: unknown names fail loudly."""

from __future__ import annotations

from html.parser import HTMLParser


class _FormParser(HTMLParser):
    def __init__(self, form_id: str | None):
        super().__init__(convert_charrefs=True)
        self.form_id = form_id
        self.in_form = False
        self.depth = 0
        self.fields: dict[str, list[str]] = {}
        self.order: list[str] = []
        self._select: str | None = None
        self._select_multi = False
        self._select_first: str | None = None
        self._select_has_selected = False
        self._option_value: str | None = None
        self._textarea: str | None = None
        self._text: list[str] = []
        self.action: str | None = None

    def _add(self, name: str, value: str) -> None:
        if name not in self.fields:
            self.fields[name] = []
            self.order.append(name)
        self.fields[name].append(value)

    def handle_starttag(self, tag, attrs):
        a = dict(attrs)
        if tag == "form" and not self.in_form:
            if self.form_id is None or a.get("id") == self.form_id:
                self.in_form = True
                self.action = a.get("action")
            return
        if not self.in_form:
            return
        name = a.get("name")
        if tag == "input" and name:
            t = (a.get("type") or "text").lower()
            if t in ("submit", "button", "image", "reset", "file"):
                return
            if t in ("checkbox", "radio"):
                if "checked" in a:
                    self._add(name, a.get("value", "on"))
                else:
                    self.fields.setdefault(name, [])
                    if name not in self.order:
                        self.order.append(name)
                return
            self._add(name, a.get("value", ""))
        elif tag == "select" and name:
            self._select, self._select_multi = name, "multiple" in a
            self._select_first, self._select_has_selected = None, False
            self.fields.setdefault(name, [])
            if name not in self.order:
                self.order.append(name)
        elif tag == "option" and self._select:
            v = a.get("value", "")
            if self._select_first is None:
                self._select_first = v
            if "selected" in a:
                self._add(self._select, v)
                self._select_has_selected = True
        elif tag == "textarea" and name:
            self._textarea, self._text = name, []

    def handle_endtag(self, tag):
        if tag == "form" and self.in_form:
            self.in_form = False
        elif tag == "select" and self._select:
            if not self._select_has_selected and not self._select_multi and self._select_first is not None:
                self._add(self._select, self._select_first)
            self._select = None
        elif tag == "textarea" and self._textarea:
            self._add(self._textarea, "".join(self._text).lstrip("\n"))
            self._textarea = None

    def handle_data(self, data):
        if self._textarea:
            self._text.append(data)


def read_form(html: str, form_id: str | None = None) -> dict[str, list[str]]:
    p = _FormParser(form_id)
    p.feed(html)
    return p.fields


def fill(fields: dict[str, list[str]], **changes) -> list[tuple[str, str]]:
    """`changes`: name -> str | list[str] | None (None or [] = unchecked/empty). Names must exist."""
    out = {k: list(v) for k, v in fields.items()}
    for name, value in changes.items():
        if name not in out:
            raise KeyError(f"form has no field {name!r}")
        out[name] = [] if value is None else ([value] if isinstance(value, str) else list(value))
    return [(k, v) for k, vals in out.items() for v in vals]
