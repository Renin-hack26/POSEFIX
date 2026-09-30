/// Shared date helpers actually used across engines, use cases and screens.
library;

extension DateTimeX on DateTime {
  /// `yyyy-MM-dd` local day bucket (meal / strike / metric keys).
  String get dateKey =>
      '$year-${month.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}';

  DateTime get startOfDay => DateTime(year, month, day);

  /// Monday 00:00 of this week (local).
  DateTime get startOfWeek {
    final d = startOfDay;
    return d.subtract(Duration(days: d.weekday - DateTime.monday));
  }
}
