import 'package:flutter_test/flutter_test.dart';
import 'package:logbook/logbook.dart';
import 'package:logbook/src/common/util/log_message_to_csv.dart';

void main() {
  final buffer = LogBuffer.instance;

  setUp(buffer.debugReset);

  LogMessage message(String text) => LogMessage(
    message: text,
    timestamp: DateTime.utc(2026, 7, 3, 12, 30, 5, 7),
    prefix: 'I',
  );

  group('toCSVString', () {
    test('starts with a BOM and the header row', () async {
      final csv = await buffer.toCSVString();

      expect(csv, startsWith('\uFEFF'));
      expect(csv.substring(1), 'prefix,timestamp,message');
    });

    test('can omit the BOM', () async {
      final csv = await buffer.toCSVString(addBomForExcel: false);

      expect(csv, startsWith('prefix,'));
    });

    test('writes ISO-8601 UTC timestamps including the date', () async {
      buffer.add(message('hello'));

      final csv = await buffer.toCSVString(addBomForExcel: false);

      expect(csv.split('\n')[1], 'I,2026-07-03T12:30:05.007Z,hello');
    });

    test('quotes commas, quotes and newlines', () async {
      buffer
        ..add(message('a,b'))
        ..add(message('say "hi"'))
        ..add(message('line1\nline2'))
        ..add(message('carriage\rreturn'));

      final csv = await buffer.toCSVString(addBomForExcel: false);
      final lines = csv.split('\n');

      expect(lines[1], endsWith('"a,b"'));
      expect(lines[2], endsWith('"say ""hi"""'));
      expect(lines[3], endsWith('"line1'));
      expect(lines[4], 'line2"');
      expect(lines[5], endsWith('"carriage\rreturn"'));
    });

    test('neutralizes spreadsheet formula injection', () async {
      buffer.add(message('=HYPERLINK("http://evil")'));

      final csv = await buffer.toCSVString(addBomForExcel: false);

      expect(csv.split('\n')[1], contains("'=HYPERLINK"));
    });
  });
}
