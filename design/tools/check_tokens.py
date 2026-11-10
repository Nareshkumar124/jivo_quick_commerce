#!/usr/bin/env python3
"""Checks the design token files (design/tools/check_tokens.py).

Plain Python 3 (3.8 or newer), standard library only, no network access.

For each *.tokens.json file it checks that:
1. the file is valid JSON;
2. every token with "$type": "color" has a #RRGGBB (or #RGB / #RRGGBBAA) value;
3. every pair in "contrast.pairs":
   - names tokens that exist (fg and bg), whose colour equals the recorded
     fgHex / bgHex (for a border token, its "color");
   - has a recorded ratio equal to the ratio recomputed from the hex values
     (to 0.01);
   - meets its level: 4.5:1 for "AA text" (unless the level says "large"),
     3:1 for "non-text" or "AA large".

Usage (from the repo root):
  python -I design/tools/check_tokens.py                  # every file in design/tokens/
  python -I design/tools/check_tokens.py design/tokens/customer.tokens.json

Exit code 0 when there are no problems, 1 otherwise.
"""
import glob
import json
import os
import re
import sys

# `python -I` leaves the script's folder off sys.path; add it so hct imports.
_HERE = os.path.dirname(os.path.abspath(__file__))
if _HERE not in sys.path:
    sys.path.insert(0, _HERE)

from hct import contrast_ratio  # noqa: E402

_HEX = re.compile(r'^#([0-9a-fA-F]{3}|[0-9a-fA-F]{6}|[0-9a-fA-F]{8})$')


def _norm(hex_value):
    h = hex_value.strip().lstrip('#').upper()
    if len(h) == 3:
        h = ''.join(ch * 2 for ch in h)
    return '#' + h[:6]


def _resolve(doc, path):
    node = doc
    for part in path.split('.'):
        if not isinstance(node, dict) or part not in node:
            return None
        node = node[part]
    if not isinstance(node, dict) or '$value' not in node:
        return None
    value = node['$value']
    if isinstance(value, dict):  # e.g. a border: {"color": ..., "width": ...}
        value = value.get('color')
    return value if isinstance(value, str) else None


def _walk_colours(node, path, problems):
    if isinstance(node, dict):
        if node.get('$type') == 'color' and '$value' in node:
            value = node['$value']
            if not isinstance(value, str) or not _HEX.match(value.strip()):
                problems.append('bad colour value at %s: %r' % (path, value))
        for key, child in node.items():
            if not key.startswith('$'):
                _walk_colours(child, path + '.' + key if path else key, problems)


def _minimum_for(level):
    level = (level or '').lower()
    if 'aa text' in level and 'large' not in level:
        return 4.5
    if 'non-text' in level or 'large' in level:
        return 3.0
    return None


def check_file(file_path):
    problems = []
    try:
        with open(file_path, encoding='utf-8') as handle:
            doc = json.load(handle)
    except (OSError, ValueError) as error:
        return ['cannot read JSON: %s' % error], 0
    for key, value in doc.items():
        if not key.startswith('$') and key != 'contrast':
            _walk_colours(value, key, problems)
    pairs = (doc.get('contrast') or {}).get('pairs') or []
    for pair in pairs:
        label = '%s on %s' % (pair.get('fg'), pair.get('bg'))
        try:
            computed = round(contrast_ratio(pair['fgHex'], pair['bgHex']), 2)
        except (KeyError, ValueError) as error:
            problems.append('%s: bad hex (%s)' % (label, error))
            continue
        if abs(computed - float(pair.get('ratio', -1))) > 0.01:
            problems.append('%s: recorded %s, computed %.2f'
                            % (label, pair.get('ratio'), computed))
        for side in ('fg', 'bg'):
            value = _resolve(doc, pair.get(side, ''))
            if value is None:
                problems.append('%s: token %s not found' % (label, pair.get(side)))
            elif _norm(value) != _norm(pair[side + 'Hex']):
                problems.append('%s: token %s is %s but %sHex is %s'
                                % (label, pair[side], value, side, pair[side + 'Hex']))
        minimum = _minimum_for(pair.get('level'))
        if minimum is not None and computed < minimum:
            problems.append('%s: %.2f is below %.1f for "%s"'
                            % (label, computed, minimum, pair.get('level')))
    return problems, len(pairs)


def main(argv):
    files = argv or sorted(glob.glob(
        os.path.join(_HERE, '..', 'tokens', '*.tokens.json')))
    if not files:
        print('No token files found.', file=sys.stderr)
        return 1
    total = 0
    for file_path in files:
        problems, pair_count = check_file(file_path)
        name = os.path.relpath(file_path)
        print('%s: %d contrast pairs, %d problems' % (name, pair_count, len(problems)))
        for problem in problems:
            print('  - ' + problem)
        total += len(problems)
    return 0 if total == 0 else 1


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
