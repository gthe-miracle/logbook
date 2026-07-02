import 'package:flutter_test/flutter_test.dart';
import 'package:logbook/logbook.dart';
import 'package:logbook/src/feature/data/logbook_repository.dart';

LogMessage _message(String prefix, [String text = 'msg']) => LogMessage(
  message: text,
  timestamp: DateTime(2026, 7, 3, 12),
  prefix: prefix,
);

void main() {
  final buffer = LogBuffer.instance;

  setUp(buffer.debugReset);

  group('add', () {
    test('stores messages and tracks prefixes', () {
      buffer
        ..add(_message('I'))
        ..add(_message('W'))
        ..add(_message('I'));

      expect(buffer.logs.length, 3);
      expect(buffer.logsPrefix, unorderedEquals(['I', 'W']));
      expect(buffer.totalLogsCount, 3);
    });

    test('evicts the oldest message beyond bufferLimit', () {
      buffer
        ..bufferLimit = 3
        ..add(_message('A', 'first'))
        ..add(_message('B'))
        ..add(_message('C'))
        ..add(_message('D'));

      expect(buffer.logs.length, 3);
      expect(buffer.logs.first.prefix, 'B');
      expect(buffer.logsPrefix, unorderedEquals(['B', 'C', 'D']));
      expect(buffer.totalLogsCount, 4);
    });
  });

  group('addAll', () {
    test('keeps the newest entries of an oversized batch', () {
      buffer
        ..bufferLimit = 3
        ..addAll([
          _message('A'),
          _message('B'),
          _message('C'),
          _message('D'),
          _message('E'),
        ]);

      expect(buffer.logs.map((log) => log.prefix), ['C', 'D', 'E']);
      expect(buffer.totalLogsCount, 3);
    });

    test('evicts existing entries to make room', () {
      buffer
        ..bufferLimit = 3
        ..add(_message('A'))
        ..add(_message('B'))
        ..addAll([_message('C'), _message('D')]);

      expect(buffer.logs.map((log) => log.prefix), ['B', 'C', 'D']);
      expect(buffer.logsPrefix, unorderedEquals(['B', 'C', 'D']));
    });
  });

  group('bufferLimit setter', () {
    test('trims existing overflow and untracks prefixes', () {
      buffer
        ..add(_message('A'))
        ..add(_message('B'))
        ..add(_message('C'))
        ..bufferLimit = 2;

      expect(buffer.logs.map((log) => log.prefix), ['B', 'C']);
      expect(buffer.logsPrefix, unorderedEquals(['B', 'C']));
    });
  });

  group('logsSince', () {
    test('returns only logs added after the marker', () {
      buffer
        ..add(_message('A'))
        ..add(_message('B'));
      final marker = buffer.totalLogsCount;
      buffer.add(_message('C'));

      expect(buffer.logsSince(marker).map((log) => log.prefix), ['C']);
    });

    test('clamps when the marker predates evicted logs', () {
      buffer
        ..bufferLimit = 2
        ..add(_message('A'))
        ..add(_message('B'))
        ..add(_message('C'));

      expect(buffer.logsSince(0).map((log) => log.prefix), ['B', 'C']);
    });

    test('is empty right after clear', () {
      buffer
        ..add(_message('A'))
        ..clear();

      expect(buffer.logsSince(0), isEmpty);
    });
  });

  test('notifications are coalesced per microtask burst', () async {
    var notifications = 0;
    void listener() => notifications++;
    buffer.addListener(listener);
    addTearDown(() => buffer.removeListener(listener));

    buffer
      ..add(_message('A'))
      ..add(_message('B'))
      ..add(_message('C'));

    await Future<void>.delayed(Duration.zero);
    expect(notifications, 1);
  });

  group('sendLogsToServer', () {
    test('returns false without a uri', () async {
      final result = await buffer.sendLogsToServer(
        uri: null,
        debugFileName: 'debug.csv',
        multipartFileFields: null,
      );

      expect(result, isFalse);
    });

    test('returns true when the repository succeeds', () async {
      final repository = _RecordingRepository();
      buffer.repository = repository;

      final result = await buffer.sendLogsToServer(
        uri: Uri.parse('https://example.com/upload'),
        debugFileName: 'debug.csv',
        multipartFileFields: const {'caption': 'test'},
      );

      expect(result, isTrue);
      expect(repository.sentFileNames, ['debug.csv']);
      expect(repository.sentFields, [
        const {'caption': 'test'},
      ]);
    });

    test('returns false and logs when the repository throws', () async {
      buffer.repository = _ThrowingRepository();

      final result = await buffer.sendLogsToServer(
        uri: Uri.parse('https://example.com/upload'),
        debugFileName: 'debug.csv',
        multipartFileFields: null,
      );

      expect(result, isFalse);
      expect(
        buffer.logs.any(
          (log) =>
              log.prefix == 'S' &&
              log.message.contains('Failed to send logs to server'),
        ),
        isTrue,
      );
    });
  });
}

final class _RecordingRepository implements ILogbookRepository {
  final List<String> sentFileNames = [];
  final List<Map<String, String>?> sentFields = [];

  @override
  Future<void> sendLog(
    Uri uri,
    List<int> bytes, {
    required String fileName,
    Map<String, String>? fields,
  }) async {
    sentFileNames.add(fileName);
    sentFields.add(fields);
  }
}

final class _ThrowingRepository implements ILogbookRepository {
  @override
  Future<void> sendLog(
    Uri uri,
    List<int> bytes, {
    required String fileName,
    Map<String, String>? fields,
  }) async {
    throw Exception('upload failed');
  }
}
