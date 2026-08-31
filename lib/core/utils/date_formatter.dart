class DateFormatter {
  /// Formats time in 12-hour AM/PM format (e.g. "2:30 PM").
  /// If [showDateIfNotToday] is true (default for chat list item previews),
  /// it returns 'DD/MM' for dates prior to today.
  static String formatTime(DateTime? dt, {bool showDateIfNotToday = true}) {
    if (dt == null) return '';
    final now = DateTime.now();
    final isToday =
        dt.day == now.day && dt.month == now.month && dt.year == now.year;
    final hour24 = dt.hour;
    final minute = dt.minute.toString().padLeft(2, '0');
    final period = hour24 >= 12 ? 'PM' : 'AM';
    final hour12 = hour24 % 12 == 0 ? 12 : hour24 % 12;
    final timeStr = '$hour12:$minute $period';

    if (isToday || !showDateIfNotToday) {
      return timeStr;
    }
    return '${dt.day}/${dt.month}';
  }

  /// Formats time in 12-hour AM/PM format (e.g. "2:30 PM") for chat bubbles.
  static String formatAmPm(DateTime? dt) {
    return formatTime(dt, showDateIfNotToday: false);
  }
}
