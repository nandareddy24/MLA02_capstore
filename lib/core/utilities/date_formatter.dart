import 'package:intl/intl.dart';

/// Standardized date and timestamp formatting utilities.
abstract final class DateFormatter {
  static final DateFormat _shortDate = DateFormat('MMM d, yyyy');
  static final DateFormat _dateTime = DateFormat('MMM d, yyyy • HH:mm');
  static final DateFormat _timeOnly = DateFormat('HH:mm');

  static String formatShortDate(DateTime dateTime) =>
      _shortDate.format(dateTime.toLocal());

  static String formatDateTime(DateTime dateTime) =>
      _dateTime.format(dateTime.toLocal());

  static String formatRelative(DateTime dateTime) {
    final now = DateTime.now();
    final diff = now.difference(dateTime.toLocal());

    if (diff.inSeconds < 60) {
      return 'Just now';
    }
    if (diff.inMinutes < 60) {
      final mins = diff.inMinutes;
      return '$mins ${mins == 1 ? 'min' : 'mins'} ago';
    }
    if (diff.inHours < 24) {
      final hrs = diff.inHours;
      return '$hrs ${hrs == 1 ? 'hr' : 'hrs'} ago';
    }
    if (diff.inDays == 1) {
      return 'Yesterday at ${_timeOnly.format(dateTime.toLocal())}';
    }
    return formatShortDate(dateTime);
  }
}
