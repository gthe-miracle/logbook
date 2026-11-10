import 'dart:developer' as developer;

import 'package:flutter/foundation.dart' show kReleaseMode;

import '../../feature/logbook/log_buffer.dart';
import '../extension/date_time_extension.dart';
import '../extension/string_buffer_extension.dart';
import '../model/console_color.dart';
import '../model/console_font.dart';
import '../model/log_message.dart';
import 'constants.dart';
import 'prefix_palette.dart';

/// Global logger instance.
final l = _L._();

/// {@template logger}
/// The logger behind the global [l] instance.
///
/// Every call stores a [LogMessage] in [LogBuffer] (shown by the in-app
/// viewer and included in server uploads) and, outside of release mode,
/// prints a colored line to the developer console.
/// {@endtemplate}
final class _L {
  /// {@macro logger}
  new _();

  /// Logs a fine/debug message (prefix `F`, black in console).
  final void Function(Object? message) f = _log(
    'F',
    font: ConsoleFont.bold.value,
    foreground: ConsoleColor.black.foregroundValue,
  );

  /// Logs a config message (prefix `C`, green in console).
  final void Function(Object? message) c = _log(
    'C',
    font: ConsoleFont.bold.value,
    foreground: ConsoleColor.green.foregroundValue,
  );

  /// Logs an info message (prefix `I`, blue in console).
  final void Function(Object? message) i = _log(
    'I',
    font: ConsoleFont.bold.value,
    foreground: ConsoleColor.blue.foregroundValue,
  );

  /// Logs a warning (prefix `W`, yellow in console) with an optional
  /// [StackTrace] and reason.
  final void Function(
    Object exception, [
    StackTrace? stackTrace,
    String? reason,
  ])
  w = _log(
    'W',
    font: ConsoleFont.bold.value,
    foreground: ConsoleColor.yellow.foregroundValue,
    background: ConsoleColor.black.backgroundValue,
  );

  /// Logs a severe error (prefix `S`, red in console) with an optional
  /// [StackTrace] and reason.
  final void Function(
    Object exception, [
    StackTrace? stackTrace,
    String? reason,
  ])
  s = _log(
    'S',
    font: ConsoleFont.bold.value,
    foreground: ConsoleColor.red.foregroundValue,
  );

  /// Logs [message] under a custom [prefix].
  ///
  /// Each distinct prefix gets its own stable color in both the console and
  /// the in-app viewer.
  void log(
    Object message,
    String prefix, {
    StackTrace? stackTrace,
    bool withMilliseconds = false,
  }) {
    final text = _messageText(message, stackTrace, null);
    LogBuffer.instance.add(
      LogMessage(message: text, timestamp: DateTime.now(), prefix: prefix),
    );

    if (kReleaseMode) return;

    final foreground = ansiForegroundForPrefix(prefix);
    final formattedMessage = _formatStyled(
      '${Constants.esc}$foreground $message',
      prefix,
      font: ConsoleFont.bold.value,
      foreground: foreground,
      withMilliseconds: withMilliseconds,
    );

    developer.log(formattedMessage, name: '•', stackTrace: stackTrace);
  }

  static void Function(
    Object? message, [
    StackTrace? stackTrace,
    String? reason,
  ])
  _log(String prefix, {String? font, String? foreground, String? background}) =>
      (message, [stackTrace, reason]) {
        final text = _messageText(message, stackTrace, reason);
        LogBuffer.instance.add(
          LogMessage(message: text, timestamp: DateTime.now(), prefix: prefix),
        );

        if (kReleaseMode) return;

        final consoleMessage = reason == null
            ? '$message'
            : '$message ($reason)';
        final formattedMessage = _formatStyled(
          '${Constants.esc}$foreground $consoleMessage',
          prefix,
          font: font,
          foreground: foreground,
          background: background,
        );

        developer.log(formattedMessage, name: '•', stackTrace: stackTrace);
      };

  /// Builds the stored message text: `message (reason)\nstackTrace`.
  static String _messageText(
    Object? message,
    StackTrace? stackTrace,
    String? reason,
  ) =>
      '$message'
      '${reason != null ? ' ($reason)' : ''}'
      '${stackTrace != null ? '\n$stackTrace' : ''}';
}

/// Formats a console line: `<styled>[prefix]</styled>[hh:mm:ss] message`.
String _formatStyled(
  Object message,
  String prefix, {
  String? font,
  String? foreground,
  String? background,
  bool withMilliseconds = false,
}) {
  final buffer = StringBuffer();
  for (final value in [font, foreground, background]) {
    if (value != null) buffer.writeEsc(value);
  }
  buffer
    ..write('[')
    ..write(prefix)
    ..write(']')
    ..writeEsc(Constants.reset);

  return buffer.completeMessage(
    '['
    '${DateTime.now().timeFormat(withMilliseconds: withMilliseconds)}'
    ']'
    '$message',
  );
}
