import 'dart:typed_data';

import 'package:http/http.dart' as http;

/// {@template i_logbook_repository}
/// Logbook repository interface.
/// {@endtemplate}
// ignore: one_member_abstracts
abstract interface class ILogbookRepository {
  /// {@macro i_logbook_repository}
  const ILogbookRepository();

  /// Sends a log file to the server.
  ///
  /// Completes normally on a 2xx response; throws on network errors,
  /// timeouts and non-2xx status codes.
  Future<void> sendLog(
    Uri uri,
    Uint8List bytes, {
    required final String fileName,
    final Map<String, String>? fields,
  });
}

/// {@template logbook_repository_impl}
/// Uploads the log file as a `multipart/form-data` POST with the file under
/// the `document` field.
/// {@endtemplate}
final class LogbookRepositoryImpl implements ILogbookRepository {
  /// {@macro logbook_repository_impl}
  ///
  /// A custom [client] can be supplied (e.g. a mock in tests); by default
  /// a short-lived client is used per request.
  const LogbookRepositoryImpl({http.Client? client}) : _client = client;

  /// Maximum time for the whole upload round-trip.
  static const Duration _timeout = Duration(seconds: 30);

  final http.Client? _client;

  @override
  Future<void> sendLog(
    Uri uri,
    Uint8List bytes, {
    required final String fileName,
    final Map<String, String>? fields,
  }) => _send(uri, bytes, fileName: fileName, fields: fields).timeout(_timeout);

  Future<void> _send(
    Uri uri,
    Uint8List bytes, {
    required final String fileName,
    final Map<String, String>? fields,
  }) async {
    final request = http.MultipartRequest('POST', uri)
      ..fields.addAll(fields ?? {})
      ..files.add(
        http.MultipartFile.fromBytes('document', bytes, filename: fileName),
      );

    final client = _client;
    final streamed = client == null
        ? await request.send()
        : await client.send(request);
    final response = await http.Response.fromStream(streamed);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw http.ClientException(
        'Log upload failed with status ${response.statusCode}: '
        '${_truncate(response.body)}',
        uri,
      );
    }
  }

  static String _truncate(String body) =>
      body.length <= 200 ? body : '${body.substring(0, 200)}…';
}
