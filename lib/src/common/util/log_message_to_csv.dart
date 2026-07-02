import 'package:flutter/foundation.dart' show compute;

import '../../feature/logbook/log_buffer.dart';

/// {@template log_message_to_csv}
/// Log message to CSV extension.
/// {@endtemplate}
extension LogMessageToCSV on LogBuffer {
  /// CSV BOM for correct csv file formatting
  static const String _csvBom = '\uFEFF';

  /// Number of rows below which the CSV is built synchronously — isolate
  /// startup costs more than the conversion itself for small buffers.
  static const int _computeThreshold = 1000;

  /// Writes a CSV file, using [compute] for off-main-thread processing when
  /// the buffer is large.
  Future<String> toCSVString({bool addBomForExcel = true}) async {
    final rows = [
      ['prefix', 'timestamp', 'message'],
      ...logs.map(
        (log) => [
          log.prefix,
          log.timestamp.toUtc().toIso8601String(),
          log.message,
        ],
      ),
    ];

    final csv = rows.length < _computeThreshold
        ? _listToCSV(rows)
        : await compute(_listToCSV, rows);

    return addBomForExcel ? '$_csvBom$csv' : csv;
  }
}

/// Cell prefixes Excel/Sheets interpret as formulas (CSV injection).
final RegExp _formulaPrefix = RegExp(r'^[=+\-@\t]');

/// Converts a list of rows to CSV format
String _listToCSV(List<List<Object?>> rows) {
  final buffer = StringBuffer();
  for (var i = 0; i < rows.length; i++) {
    final row = rows[i];

    for (var j = 0; j < row.length; j++) {
      var value = row[j]?.toString() ?? '';

      // Neutralize spreadsheet formula injection.
      if (_formulaPrefix.hasMatch(value)) value = "'$value";

      if (value.contains(',') ||
          value.contains('"') ||
          value.contains('\n') ||
          value.contains('\r')) {
        buffer.write('"${value.replaceAll('"', '""')}"');
      } else {
        buffer.write(value);
      }

      if (j < row.length - 1) buffer.write(',');
    }
    if (i < rows.length - 1) buffer.write('\n');
  }

  return buffer.toString();
}
