import 'package:flutter_test/flutter_test.dart';
import 'package:logbook/src/common/extension/date_time_extension.dart';

void main() {
  group('timeFormat', () {
    test('pads hours, minutes and seconds to two digits', () {
      expect(DateTime(2026, 7, 3, 1, 2, 3).timeFormat(), '01:02:03');
    });

    test('pads milliseconds to three digits', () {
      expect(
        DateTime(2026, 7, 3, 12, 0, 5, 7).timeFormat(withMilliseconds: true),
        '12:00:05.007',
      );
      expect(
        DateTime(2026, 7, 3, 12, 0, 5, 70).timeFormat(withMilliseconds: true),
        '12:00:05.070',
      );
      expect(
        DateTime(2026, 7, 3, 12, 0, 5, 700).timeFormat(withMilliseconds: true),
        '12:00:05.700',
      );
    });

    test('omits milliseconds by default', () {
      expect(DateTime(2026, 7, 3, 12, 0, 5, 700).timeFormat(), '12:00:05');
    });
  });
}
