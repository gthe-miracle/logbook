import 'package:flutter/foundation.dart';

import '../extension/date_time_extension.dart';

/// {@template log_message}
/// A single immutable log entry held by the log buffer: a [prefix]
/// (level or custom tag), the [message] text, and the [timestamp] it was
/// recorded at.
/// {@endtemplate}
@immutable
final class LogMessage {
  /// {@macro log_message}
  const LogMessage({
    required this.message,
    required this.timestamp,
    required this.prefix,
  });

  /// The prefix of the log message, e.g. `I`, `W`, `S` or a custom tag.
  final String prefix;

  /// The text of the log message.
  final String message;

  /// The moment the log message was recorded (local time).
  final DateTime timestamp;

  /// The time-of-day of [timestamp] in the format `hh:mm:ss.mmm`.
  String get formattedTime => timestamp.timeFormat(withMilliseconds: true);

  @override
  String toString() => '[$prefix]\t[$formattedTime]\t$message';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LogMessage &&
          other.prefix == prefix &&
          other.message == message &&
          other.timestamp == timestamp;

  @override
  int get hashCode => Object.hash(prefix, message, timestamp);
}
