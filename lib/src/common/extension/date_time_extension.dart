/// Extension methods for [DateTime].
extension DateTimeX on DateTime {
  /// Formats the time-of-day to a string.
  /// example:
  ///   DateTime(2021, 1, 1, 12, 0, 0).timeFormat() -> 12:00:00 (hh:mm:ss)
  ///   DateTime(2021, 1, 1, 12, 0, 0, 7).timeFormat(withMilliseconds: true)
  ///     -> 12:00:00.007 (hh:mm:ss.mmm)
  String timeFormat({bool withMilliseconds = false}) {
    String pad2(int value) => value.toString().padLeft(2, '0');

    final millisecondsString = withMilliseconds
        ? '.${millisecond.toString().padLeft(3, '0')}'
        : '';

    return '${pad2(hour)}:${pad2(minute)}:${pad2(second)}$millisecondsString';
  }
}
