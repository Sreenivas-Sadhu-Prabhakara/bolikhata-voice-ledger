/// Dates, written the way a shop ledger writes them.
///
/// Deliberately hand-rolled and English-only rather than pulling in a
/// localisation package: the app shows at most a day and a month, and a
/// dependency has to earn its place.
///
/// Pure Dart: nothing in `lib/domain/` imports Flutter.
library;

/// Short month names, January first.
const List<String> monthNames = <String>[
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

/// `YYYY-MM-DD`, in the phone's own time zone. Used by the export file.
String formatDate(DateTime at) {
  final m = at.month.toString().padLeft(2, '0');
  final d = at.day.toString().padLeft(2, '0');
  return '${at.year}-$m-$d';
}

/// `HH:MM` on a 24-hour clock, in the phone's own time zone.
String formatTime(DateTime at) {
  final h = at.hour.toString().padLeft(2, '0');
  final m = at.minute.toString().padLeft(2, '0');
  return '$h:$m';
}

/// `10 Jan`, or `10 Jan 2025` when [at] is not in [now]'s year.
String formatDayMonth(DateTime at, {required DateTime now}) {
  final month = monthNames[at.month - 1];
  if (at.year == now.year) return '${at.day} $month';
  return '${at.day} $month ${at.year}';
}

/// What to put next to an entry in a list: `Today`, `Yesterday`, or a date.
String formatDayLabel(DateTime at, {required DateTime now}) {
  final days = _dayNumber(now) - _dayNumber(at);
  if (days == 0) return 'Today';
  if (days == 1) return 'Yesterday';
  return formatDayMonth(at, now: now);
}

/// Counts the calendar day [at] falls on, so that "yesterday" means a
/// different day on the wall calendar rather than 24 hours ago.
///
/// The year, month and day are read in local time and then measured in UTC,
/// which keeps the count exact in a zone that shifts for daylight saving.
int _dayNumber(DateTime at) =>
    DateTime.utc(at.year, at.month, at.day).millisecondsSinceEpoch ~/
    Duration.millisecondsPerDay;
