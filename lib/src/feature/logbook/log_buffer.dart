import 'dart:async' show scheduleMicrotask;
import 'dart:collection' show Queue;
import 'dart:convert';

import 'package:flutter/foundation.dart' show ChangeNotifier, visibleForTesting;

import '../../../logbook.dart';
import '../../common/util/log_message_to_csv.dart';
import '../data/logbook_repository.dart';

/// {@template log_buffer}
/// In-memory ring buffer of [LogMessage]s shared by the logger, the in-app
/// viewer and the server upload. Notifies listeners (coalesced per
/// microtask) whenever its contents change.
/// {@endtemplate}
final class LogBuffer with ChangeNotifier {
  /// {@macro log_buffer}
  LogBuffer._internal();

  /// {@macro log_buffer_instance}
  static final LogBuffer _instance = LogBuffer._internal();

  ILogbookRepository _logbookRepository = const LogbookRepositoryImpl();

  /// The upload repository (tests only).
  @visibleForTesting
  ILogbookRepository get repository => _logbookRepository;

  /// Replaces the upload repository (tests only).
  @visibleForTesting
  set repository(ILogbookRepository value) => _logbookRepository = value;

  /// The shared singleton instance.
  static LogBuffer get instance => _instance;

  /// Maximum number of messages kept; the oldest are evicted beyond it.
  /// Configured via [LogbookConfig.bufferLimit] (applied by [Logbook.config]).
  int _bufferLimit = LogbookConfig.defaultBufferLimit;

  /// Maximum number of log messages kept in memory.
  int get bufferLimit => _bufferLimit;

  set bufferLimit(int value) {
    assert(value > 0, 'bufferLimit must be positive');
    if (value <= 0 || value == _bufferLimit) return;
    _bufferLimit = value;
    var changed = false;
    while (_queue.length > _bufferLimit) {
      _untrackPrefix(_queue.first.prefix);
      _queue.removeFirst();
      changed = true;
    }
    if (changed) _scheduleNotification();
  }

  /// Queue
  final Queue<LogMessage> _queue = Queue<LogMessage>();

  /// Prefix occurrence counts — avoids O(n) iteration for prefix lookups
  final Map<String, int> _prefixCounts = {};

  /// Notification scheduled
  bool _notificationScheduled = false;

  /// Total logs count (monotonically increasing, never clamped)
  int _totalLogsCount = 0;

  /// This is the total logs count ever added (not clamped by eviction).
  int get totalLogsCount => _totalLogsCount;

  /// Get the logs
  Iterable<LogMessage> get logs => _queue;

  /// Get the logs prefix — O(1) via tracked map keys
  Iterable<String> get logsPrefix => _prefixCounts.keys;

  /// Clear the logs
  void clear() {
    _queue.clear();
    _prefixCounts.clear();
    _scheduleNotification();
  }

  /// Add a log to the buffer
  void add(LogMessage log) {
    if (_queue.length >= _bufferLimit) {
      _untrackPrefix(_queue.first.prefix);
      _queue.removeFirst();
    }
    _queue.add(log);
    _trackPrefix(log.prefix);
    _totalLogsCount++;
    _scheduleNotification();
  }

  /// Add a list of logs to the buffer.
  ///
  /// When [logs] exceeds [bufferLimit], only the newest [bufferLimit]
  /// entries are kept.
  void addAll(List<LogMessage> logs) {
    final list = logs.length > _bufferLimit
        ? logs.sublist(logs.length - _bufferLimit)
        : logs;
    if (_queue.length + list.length > _bufferLimit) {
      final toRemove = _queue.length + list.length - _bufferLimit;
      for (var i = 0; i < toRemove; i++) {
        _untrackPrefix(_queue.first.prefix);
        _queue.removeFirst();
      }
    }
    for (final log in list) {
      _trackPrefix(log.prefix);
    }
    _queue.addAll(list);
    _totalLogsCount += list.length;
    _scheduleNotification();
  }

  void _trackPrefix(String prefix) {
    _prefixCounts[prefix] = (_prefixCounts[prefix] ?? 0) + 1;
  }

  void _untrackPrefix(String prefix) {
    final count = _prefixCounts[prefix];
    if (count == null) return;
    if (count <= 1) {
      _prefixCounts.remove(prefix);
    } else {
      _prefixCounts[prefix] = count - 1;
    }
  }

  /// Returns logs added after [sinceCount] total additions.
  Iterable<LogMessage> logsSince(int sinceCount) {
    final available = _queue.length;
    final newCount = (_totalLogsCount - sinceCount).clamp(0, available);
    return _queue.skip(available - newCount);
  }

  /// Coalesces notifications: many adds in one microtask burst produce a
  /// single [notifyListeners] call.
  void _scheduleNotification() {
    if (_notificationScheduled) return;
    _notificationScheduled = true;
    scheduleMicrotask(() {
      _notificationScheduled = false;
      notifyListeners();
    });
  }

  /// Sends the buffered logs to the server as a CSV multipart upload.
  ///
  /// Returns true on success, false when [uri] is null or the upload failed
  /// (the failure is also logged via [l.s]).
  Future<bool> sendLogsToServer({
    required final Uri? uri,
    required final String debugFileName,
    required final Map<String, String>? multipartFileFields,
  }) async {
    if (uri == null) return false;

    try {
      final file = await toCSVString();
      final bytes = utf8.encode(file);

      await _logbookRepository.sendLog(
        uri,
        bytes,
        fileName: debugFileName,
        fields: multipartFileFields,
      );
      return true;
    } on Object catch (e, s) {
      l.s('Failed to send logs to server: $e', s);
      return false;
    }
  }

  /// Resets the buffer to its initial state (tests only).
  @visibleForTesting
  void debugReset() {
    _queue.clear();
    _prefixCounts.clear();
    _totalLogsCount = 0;
    _bufferLimit = LogbookConfig.defaultBufferLimit;
    _logbookRepository = const LogbookRepositoryImpl();
  }

  @override
  void dispose() {
    _queue.clear();
    _prefixCounts.clear();
    super.dispose();
  }
}
