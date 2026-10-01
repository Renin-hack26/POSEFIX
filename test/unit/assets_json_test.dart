/// Bundled JSON assets must be byte-clean: no UTF-8 BOM and decodable
/// exactly the way the app reads them at runtime.
///
/// `rootBundle.loadString` → `utf8.decode` (NO BOM stripping) → `jsonDecode`
/// — and Dart's jsonDecode throws `FormatException` on a leading BOM. A
/// Windows editor silently adding a BOM to `plan_templates.json` broke plan
/// generation on-device while every widget test stayed green (tests read
/// files via `dart:io`, which strips BOMs). This test reads raw bytes to
/// reproduce the runtime path.
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('every assets/data JSON file loads without a BOM (runtime path)',
      () async {
    final files = Directory('assets/data')
        .listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith('.json'))
        .toList();
    expect(files, isNotEmpty, reason: 'assets/data/*.json should exist');

    for (final file in files) {
      final bytes = await file.readAsBytes();
      final hasBom = bytes.length >= 3 &&
          bytes[0] == 0xEF &&
          bytes[1] == 0xBB &&
          bytes[2] == 0xBF;
      expect(hasBom, isFalse,
          reason: '${file.path} starts with a UTF-8 BOM — rootBundle.'
              'loadString would hand a "\uFEFF…" string to jsonDecode, '
              'which throws at runtime');
      // Same decode chain as ContentLoader: utf8.decode → jsonDecode.
      expect(() => jsonDecode(utf8.decode(bytes)), returnsNormally,
          reason: '${file.path} must decode like the app does');
    }
  });
}
