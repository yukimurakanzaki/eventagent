#!/usr/bin/env python3
"""Extracts every tr('...') source string from lib/ into tool/l10n_keys.json.

Usage: python3 tool/l10n_extract.py  (from the mobile/ directory)
Translators fill lib/l10n/translations/<code>.dart; test/l10n_catalog_test.dart
fails when a key is missing or a {placeholder} differs.
"""
import json, pathlib, re

ROOT = pathlib.Path(__file__).resolve().parent.parent
PATTERN = re.compile(r"\btr\(\s*'((?:[^'\\]|\\.)*)'", re.S)


def unescape(raw: str) -> str:
    out, i = [], 0
    while i < len(raw):
        c = raw[i]
        if c == '\\' and i + 1 < len(raw):
            n = raw[i + 1]
            out.append({'n': '\n', 't': '\t', "'": "'", '"': '"', '\\': '\\', '$': '$'}.get(n, n))
            i += 2
        else:
            out.append(c)
            i += 1
    return ''.join(out)


def main():
    keys = {}
    for path in sorted((ROOT / 'lib').rglob('*.dart')):
        if 'l10n/translations' in path.as_posix():
            continue
        for match in PATTERN.finditer(path.read_text(encoding='utf-8')):
            key = unescape(match.group(1))
            keys.setdefault(key, path.relative_to(ROOT).as_posix())
    out = ROOT / 'tool' / 'l10n_keys.json'
    out.write_text(json.dumps(sorted(keys), ensure_ascii=False, indent=1) + '\n', encoding='utf-8')
    print(f'{len(keys)} keys -> {out.relative_to(ROOT)}')


if __name__ == '__main__':
    main()
