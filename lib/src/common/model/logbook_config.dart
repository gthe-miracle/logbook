import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart' show ThemeMode;

/// {@template logbook_config}
/// Configuration for the [Logbook] overlay and log collection.
/// {@endtemplate}
@immutable
class LogbookConfig {
  /// {@macro logbook_config}
  const new({
    this.uri,
    this.multipartFileFields,
    this.debugFileName = 'debug_info.csv',
    this.enabled = kDebugMode,
    this.fontFamily = 'FreeMono',
    this.themeMode = ThemeMode.system,
    this.bufferLimit = defaultBufferLimit,
  }) : assert(bufferLimit > 0, 'bufferLimit must be positive');

  /// Default maximum number of log messages kept in memory.
  static const int defaultBufferLimit = 32768;

  /// Your server URI.
  final Uri? uri;

  /// Your multipart file fields.
  final Map<String, String>? multipartFileFields;

  /// Debug file name to display file name in the message.
  final String debugFileName;

  /// Whether to enable the logbook overlay.
  ///
  /// Log collection into the buffer is independent of this flag, so
  /// [Logbook.sendLogsToServer] keeps working while the overlay is disabled.
  final bool enabled;

  /// Font family to use for the logbook viewer.
  ///
  /// The default `'FreeMono'` takes effect only if your app bundles a font
  /// family with that name (see the example app); otherwise Flutter silently
  /// falls back to the default font.
  final String fontFamily;

  /// Theme mode to use for changing the theme of the logbook.
  final ThemeMode themeMode;

  /// Maximum number of log messages kept in memory (oldest are evicted).
  ///
  /// Applies in all build modes — release builds also collect logs so they
  /// can be uploaded via [Logbook.sendLogsToServer].
  final int bufferLimit;

  /// Copy with.
  LogbookConfig copyWith({
    Uri? uri,
    Map<String, String>? multipartFileFields,
    String? debugFileName,
    bool? enabled,
    String? fontFamily,
    ThemeMode? themeMode,
    int? bufferLimit,
  }) => LogbookConfig(
    uri: uri ?? this.uri,
    multipartFileFields: multipartFileFields ?? this.multipartFileFields,
    debugFileName: debugFileName ?? this.debugFileName,
    enabled: enabled ?? this.enabled,
    fontFamily: fontFamily ?? this.fontFamily,
    themeMode: themeMode ?? this.themeMode,
    bufferLimit: bufferLimit ?? this.bufferLimit,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LogbookConfig &&
          other.uri == uri &&
          mapEquals(other.multipartFileFields, multipartFileFields) &&
          other.debugFileName == debugFileName &&
          other.enabled == enabled &&
          other.fontFamily == fontFamily &&
          other.themeMode == themeMode &&
          other.bufferLimit == bufferLimit;

  @override
  int get hashCode {
    final fields = multipartFileFields;
    return Object.hash(
      uri,
      fields == null
          ? null
          : Object.hashAllUnordered(
              fields.entries.map((e) => Object.hash(e.key, e.value)),
            ),
      debugFileName,
      enabled,
      fontFamily,
      themeMode,
      bufferLimit,
    );
  }

  @override
  String toString() =>
      'LogbookConfig('
      'uri: $uri, '
      'multipartFileFields: $multipartFileFields, '
      'debugFileName: $debugFileName, '
      'enabled: $enabled, '
      'fontFamily: $fontFamily, '
      'themeMode: $themeMode, '
      'bufferLimit: $bufferLimit)';
}
