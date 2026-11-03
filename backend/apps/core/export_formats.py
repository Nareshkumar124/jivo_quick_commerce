"""File formats for the admin's import/export (django-import-export), CSV and Excel only (05 §2),
with spreadsheet formula-injection escaping on export.

django-import-export 4.4.4's own `IMPORT_EXPORT_ESCAPE_FORMULAE_ON_EXPORT` step drops a single
leading "=" only (so "==1+1" still becomes a formula, and "+", "-", "@" are not handled) and
turns every cell into text (None becomes "None"). These formats keep that setting's hook but
replace the step: a text cell that a spreadsheet would evaluate (starting with = + - @, a tab or
a carriage return) gets an apostrophe in front (OWASP CSV-injection guidance). Plain numbers
such as "-3" or "+919876543210" and non-text cells are left as they are.
"""

import re

from import_export.formats import base_formats

FORMULA_PREFIXES = ("=", "+", "-", "@", "\t", "\r")
_PLAIN_NUMBER = re.compile(r"[+-]?[0-9]+(?:\.[0-9]+)?")


def escape_formula(value):
    """`"=HYPERLINK(...)"` -> `"'=HYPERLINK(...)"`; anything harmless is returned unchanged."""
    if (
        isinstance(value, str)
        and value.startswith(FORMULA_PREFIXES)
        and not _PLAIN_NUMBER.fullmatch(value)
    ):
        return f"'{value}"
    return value


class _EscapeFormulaeMixin:
    def _escape_formulae(self, dataset) -> None:
        for _ in range(dataset.height):
            row = dataset.lpop()
            dataset.append([escape_formula(cell) for cell in row])


class CSV(_EscapeFormulaeMixin, base_formats.CSV):
    pass


class XLSX(_EscapeFormulaeMixin, base_formats.XLSX):
    pass


FORMATS = [CSV, XLSX]
