import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:wargakas_mobile/l10n/l10n.dart';

/// Every tr('...') source string in lib/ must be translated in every
/// shipped language with the same {placeholders}. Run
/// `python3 tool/l10n_extract.py` and update tool/l10n/<code>.json, then
/// `python3 tool/l10n_generate.py <codes>` when this fails.
void main() {
  final pattern = RegExp(r"\btr\(\s*'((?:[^'\\]|\\.)*)'", dotAll: true);
  final placeholder = RegExp(r'\{([a-zA-Z_][a-zA-Z0-9_]*)\}');

  String unescape(String raw) => raw.replaceAllMapped(
    RegExp(r'\\(.)', dotAll: true),
    (m) => switch (m[1]) {
      'n' => '\n',
      't' => '\t',
      final other => other!,
    },
  );

  final keys = <String>{};
  for (final entity in Directory('lib').listSync(recursive: true)) {
    if (entity is! File || !entity.path.endsWith('.dart')) continue;
    if (entity.path.contains('l10n${Platform.pathSeparator}translations')) {
      continue;
    }
    for (final match in pattern.allMatches(entity.readAsStringSync())) {
      keys.add(unescape(match[1]!));
    }
  }

  test('source strings were found', () {
    expect(keys.length, greaterThan(400));
  });

  for (final language in L10n.languages) {
    if (language.code == L10n.source) continue;
    test(
      '${language.code} translates every string with matching placeholders',
      () {
        final catalog = L10n.catalogs[language.code]!;
        final missing = keys.where((key) => !catalog.containsKey(key)).toList();
        expect(missing, isEmpty, reason: 'missing ${missing.length} keys');
        final broken = <String>[];
        for (final key in keys) {
          final wanted = placeholder.allMatches(key).map((m) => m[1]).toSet();
          final got = placeholder
              .allMatches(catalog[key]!)
              .map((m) => m[1])
              .toSet();
          if (wanted.length != got.length || !wanted.containsAll(got)) {
            broken.add(key);
          }
        }
        expect(broken, isEmpty, reason: 'placeholder mismatch');
      },
    );
  }
}
