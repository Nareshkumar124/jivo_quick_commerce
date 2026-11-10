"""Helpers to read the Amazon listing workbook (read-only, no macros). stdlib + openpyxl."""
import re
import openpyxl

def load(path):
    wb = openpyxl.load_workbook(path, read_only=True, data_only=True, keep_vba=False)
    out = []
    for ws in wb.worksheets:
        if not ws.title.startswith("Template-"):
            continue
        rows = list(ws.iter_rows(values_only=True))
        ix = {k: i for i, k in enumerate(rows[3]) if k}
        for n, r in enumerate(rows[6:], start=7):
            if not any(v not in (None, "") for v in r):
                continue
            d = {k: (r[i] if i < len(r) else None) for k, i in ix.items()}
            d["_sheet"] = ws.title
            d["_row"] = n
            out.append(d)
    return out

def clean(v):
    if v is None:
        return ""
    s = str(v).replace("\u00a0", " ").replace("\ufffd", "").strip()
    return re.sub(r"\s+", " ", s)
