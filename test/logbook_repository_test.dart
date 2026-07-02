import 'dart:async';
import 'dart:typed_data';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:logbook/src/feature/data/logbook_repository.dart';

void main() {
  final uri = Uri.parse('https://example.com/upload');
  final bytes = Uint8List.fromList([1, 2, 3]);

  group('LogbookRepositoryImpl', () {
    test('completes on a 2xx response with a non-JSON body', () async {
      final client = MockClient((request) async => http.Response('OK', 200));
      final repository = LogbookRepositoryImpl(client: client);

      await expectLater(
        repository.sendLog(uri, bytes, fileName: 'debug.csv'),
        completes,
      );
    });

    test('sends the file and fields as multipart form data', () async {
      late http.Request received;
      final client = MockClient((request) async {
        received = request;
        return http.Response('', 204);
      });
      final repository = LogbookRepositoryImpl(client: client);

      await repository.sendLog(
        uri,
        bytes,
        fileName: 'debug.csv',
        fields: const {'caption': '#logbook'},
      );

      expect(received.method, 'POST');
      expect(received.url, uri);
      expect(
        received.headers['content-type'],
        startsWith('multipart/form-data'),
      );
      final body = String.fromCharCodes(received.bodyBytes);
      expect(body, contains('name="caption"'));
      expect(body, contains('#logbook'));
      expect(body, contains('filename="debug.csv"'));
    });

    test('throws on a non-2xx status code', () async {
      final client = MockClient(
        (request) async => http.Response('server exploded', 500),
      );
      final repository = LogbookRepositoryImpl(client: client);

      await expectLater(
        repository.sendLog(uri, bytes, fileName: 'debug.csv'),
        throwsA(
          isA<http.ClientException>().having(
            (e) => e.message,
            'message',
            contains('500'),
          ),
        ),
      );
    });

    test('times out when the server never responds', () {
      fakeAsync((async) {
        final client = MockClient(
          (request) => Completer<http.Response>().future,
        );
        final repository = LogbookRepositoryImpl(client: client);

        Object? error;
        repository
            .sendLog(uri, bytes, fileName: 'debug.csv')
            .then<void>((_) {}, onError: (Object e) => error = e);

        async.elapse(const Duration(seconds: 31));
        expect(error, isA<TimeoutException>());
      });
    });
  });
}
