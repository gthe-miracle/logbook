import 'package:flutter_test/flutter_test.dart';
import 'package:logbook/logbook.dart';

void main() {
  final buffer = LogBuffer.instance;

  setUp(buffer.debugReset);

  group('l', () {
    test('level methods store messages under their prefixes', () {
      l
        ..f('fine')
        ..c('config')
        ..i('info')
        ..w('warning')
        ..s('severe');

      expect(buffer.logs.map((log) => log.prefix), ['F', 'C', 'I', 'W', 'S']);
      expect(buffer.logs.first.message, 'fine');
    });

    test('w and s append the reason to the stored message', () {
      l
        ..w('latency is high', null, 'Performance')
        ..s('request failed', null, 'API');

      expect(buffer.logs.first.message, 'latency is high (Performance)');
      expect(buffer.logs.last.message, 'request failed (API)');
    });

    test('stack traces are appended to the stored message', () {
      final trace = StackTrace.current;
      l.s('boom', trace);

      expect(buffer.logs.single.message, 'boom\n$trace');
    });

    test('log stores custom prefixes', () {
      l.log('custom event', 'CUSTOM');

      final message = buffer.logs.single;
      expect(message.prefix, 'CUSTOM');
      expect(message.message, 'custom event');
    });
  });
}
