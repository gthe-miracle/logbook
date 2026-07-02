import 'package:flutter/material.dart' show ThemeMode;
import 'package:flutter_test/flutter_test.dart';
import 'package:logbook/logbook.dart';

void main() {
  group('LogbookConfig', () {
    test('copyWith replaces only the given fields', () {
      final config = LogbookConfig(uri: Uri.parse('https://a.test'));

      final copy = config.copyWith(
        enabled: false,
        themeMode: ThemeMode.dark,
        bufferLimit: 42,
      );

      expect(copy.uri, config.uri);
      expect(copy.enabled, isFalse);
      expect(copy.themeMode, ThemeMode.dark);
      expect(copy.bufferLimit, 42);
      expect(copy.debugFileName, config.debugFileName);
    });

    test('== is deep on multipartFileFields', () {
      final a = LogbookConfig(
        uri: Uri.parse('https://a.test'),
        multipartFileFields: Map.of({'k': 'v'}),
      );
      final b = LogbookConfig(
        uri: Uri.parse('https://a.test'),
        multipartFileFields: Map.of({'k': 'v'}),
      );

      expect(a, b);
    });

    test('equal configs have equal hash codes', () {
      final a = LogbookConfig(multipartFileFields: Map.of({'k': 'v'}));
      final b = LogbookConfig(multipartFileFields: Map.of({'k': 'v'}));

      expect(a.hashCode, b.hashCode);
    });

    test('== returns false for other types instead of throwing', () {
      const config = LogbookConfig();

      // ignore: unrelated_type_equality_checks
      expect(config == 'not a config', isFalse);
    });

    test('rejects a non-positive bufferLimit', () {
      expect(
        () => LogbookConfig(bufferLimit: 0),
        throwsA(isA<AssertionError>()),
      );
    });
  });
}
