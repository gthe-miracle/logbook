import 'package:flutter_test/flutter_test.dart';
import 'package:logbook/src/common/util/logger_colors.dart';
import 'package:logbook/src/common/util/prefix_palette.dart';

void main() {
  const colors = LoggerColors.dark;

  group('colorForPrefix', () {
    test('built-in prefixes keep their semantic colors', () {
      expect(colorForPrefix('S', colors), colors.consoleRed);
      expect(colorForPrefix('W', colors), colors.consoleYellow);
      expect(colorForPrefix('I', colors), colors.consoleWhite);
      expect(colorForPrefix('C', colors), colors.consoleGreen);
      expect(colorForPrefix('F', colors), colors.consoleBlack);
    });

    test('custom prefixes get a stable palette color', () {
      final first = colorForPrefix('NETWORK', colors);
      final second = colorForPrefix('NETWORK', colors);

      expect(first, second);
      expect(kPrefixPalette, contains(first));
    });
  });

  group('ansiForegroundForPrefix', () {
    test('built-in prefixes use the 8-color codes', () {
      expect(ansiForegroundForPrefix('S'), '31m');
      expect(ansiForegroundForPrefix('I'), '34m');
    });

    test('custom prefixes emit well-formed 24-bit color values', () {
      final value = ansiForegroundForPrefix('NETWORK');

      expect(value, matches(r'^38;2;\d{1,3};\d{1,3};\d{1,3}m$'));
      expect(ansiForegroundForPrefix('NETWORK'), value);
    });
  });
}
