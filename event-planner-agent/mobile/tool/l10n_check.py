#!/usr/bin/env python3
"""Validates tool/l10n/<code>.json against tool/l10n_keys.json.

Usage: python3 tool/l10n_check.py <code> [<code> ...]
Checks: every key present, no extra keys, non-empty values, identical
{placeholder} sets, and that line breaks are kept.
"""
import json, pathlib, re, sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
PH = re.compile(r'\{([a-zA-Z_][a-zA-Z0-9_]*)\}')


def check(code):
    keys = json.loads((ROOT / 'tool' / 'l10n_keys.json').read_text(encoding='utf-8'))
    path = ROOT / 'tool' / 'l10n' / f'{code}.json'
    data = json.loads(path.read_text(encoding='utf-8'))
    problems = []
    for key in keys:
        if key not in data:
            problems.append(f'missing: {key!r}')
            continue
        value = data[key]
        if not isinstance(value, str) or not value.strip():
            problems.append(f'empty: {key!r}')
            continue
        if set(PH.findall(key)) != set(PH.findall(value)):
            problems.append(f'placeholders differ: {key!r} -> {value!r}')
        if key.count('\n') and not value.count('\n'):
            problems.append(f'line breaks lost: {key!r}')
    for extra in sorted(set(data) - set(keys)):
        base = extra[:-4] if extra.endswith('|one') else None
        if base in keys:
            # Optional singular form, used when {count} == 1.
            if set(PH.findall(base)) != set(PH.findall(data[extra])):
                problems.append(f'placeholders differ: {extra!r}')
            continue
        problems.append(f'extra key (remove): {extra!r}')
    return problems


if __name__ == '__main__':
    failed = False
    for code in sys.argv[1:]:
        problems = check(code)
        print(f'{code}: {"OK" if not problems else str(len(problems)) + " problem(s)"}')
        for p in problems[:50]:
            print('  ' + p)
        failed |= bool(problems)
    sys.exit(1 if failed else 0)
