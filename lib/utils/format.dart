/// Display formatting helpers shared across screens.
library;

const _months = [
  'January', 'February', 'March', 'April', 'May', 'June',
  'July', 'August', 'September', 'October', 'November', 'December',
];

const _weekdays = [
  'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun',
];

String _mon3(int month) => _months[month - 1].substring(0, 3);

String _two(int n) => n.toString().padLeft(2, '0');

String _groupDigits(String digits) {
  final buf = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    final posFromEnd = digits.length - i;
    buf.write(digits[i]);
    if (posFromEnd > 1 && posFromEnd % 3 == 1) buf.write(',');
  }
  return buf.toString();
}

/// "৳12,000" — taka sign plus en-US style grouping.
String fmtTaka(int n) => '৳${_groupDigits('$n')}';

/// Bare grouped number for the big amount input ("12,000").
String fmtAmount(int n) => _groupDigits('$n');

/// "09:41" style 24-hour time.
String timeShort(DateTime d) => '${_two(d.hour)}:${_two(d.minute)}';

/// "Aug 29" style short date.
String dateShort(DateTime d) => '${_mon3(d.month)} ${d.day}';

/// Group-header label for a calendar day: "Today", "Yesterday",
/// or "Tue, Aug 25" (year appended when it differs from [now]'s year).
String dayGroupTitle(DateTime d, DateTime now) {
  final today = DateTime(now.year, now.month, now.day);
  final that = DateTime(d.year, d.month, d.day);
  final diff = today.difference(that).inDays;
  if (diff == 0) return 'Today';
  if (diff == 1) return 'Yesterday';
  final base =
      '${_weekdays[d.weekday - 1]}, ${_mon3(d.month)} ${d.day}';
  return d.year == now.year ? base : '$base ${d.year}';
}

/// Month label used by the summary chip ("August").
String monthName(int month) => _months[month - 1];

/// Date-row label in the sheet: "Today · Sat, Aug 29" for the current day,
/// otherwise "Sat, Aug 29" (year appended when it differs from [now]'s year).
String dateRowLabel(DateTime d, {DateTime? now}) {
  now ??= DateTime.now();
  final base = '${_weekdays[d.weekday - 1]}, ${_mon3(d.month)} ${d.day}';
  final label = d.year == now.year ? base : '$base ${d.year}';
  final isToday = d.year == now.year && d.month == now.month && d.day == now.day;
  return isToday ? 'Today · $label' : label;
}
