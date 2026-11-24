import 'package:bolikhata/domain/dates.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('formatDate', () {
    test('is ISO and zero padded', () {
      expect(formatDate(DateTime(2026, 1, 1)), '2026-01-01');
      expect(formatDate(DateTime(2026, 2, 3, 23, 59)), '2026-02-03');
      expect(formatDate(DateTime(2026, 12, 31)), '2026-12-31');
    });
  });

  group('formatTime', () {
    test('is a zero-padded 24-hour clock', () {
      expect(formatTime(DateTime(2026, 2, 3)), '00:00');
      expect(formatTime(DateTime(2026, 2, 3, 7, 5)), '07:05');
      expect(formatTime(DateTime(2026, 2, 3, 23, 59)), '23:59');
      expect(formatTime(DateTime(2026, 2, 3, 12, 0)), '12:00');
    });
  });

  group('formatDayMonth', () {
    final now = DateTime(2026, 6, 15);

    test('leaves the year off inside the current year', () {
      expect(formatDayMonth(DateTime(2026, 1, 10), now: now), '10 Jan');
      expect(formatDayMonth(DateTime(2026, 12, 31), now: now), '31 Dec');
    });

    test('shows the year for any other year', () {
      expect(formatDayMonth(DateTime(2025, 11, 2), now: now), '2 Nov 2025');
      expect(formatDayMonth(DateTime(2027, 3, 1), now: now), '1 Mar 2027');
    });

    test('covers every month', () {
      expect(monthNames, hasLength(12));
      for (var month = 1; month <= 12; month++) {
        expect(
          formatDayMonth(DateTime(2026, month, 1), now: now),
          '1 ${monthNames[month - 1]}',
        );
      }
    });
  });

  group('formatDayLabel', () {
    final now = DateTime(2026, 6, 15, 10, 30);

    const expectations = <(String, int, int, int, String)>[
      ('the same day, earlier', 2026, 6, 15, 'Today'),
      ('the day before', 2026, 6, 14, 'Yesterday'),
      ('two days before', 2026, 6, 13, '13 Jun'),
      ('last month', 2026, 5, 31, '31 May'),
      ('last year', 2025, 12, 31, '31 Dec 2025'),
    ];

    for (final (what, y, m, d, expected) in expectations) {
      test('$what is "$expected"', () {
        expect(formatDayLabel(DateTime(y, m, d, 23, 59), now: now), expected);
      });
    }

    test('one minute past midnight is still today', () {
      expect(formatDayLabel(DateTime(2026, 6, 15, 0, 1), now: now), 'Today');
    });

    test('late yesterday is still yesterday, not 24 hours ago', () {
      expect(
        formatDayLabel(DateTime(2026, 6, 14, 23, 59), now: now),
        'Yesterday',
      );
    });

    test('a date in the future falls through to a plain date', () {
      expect(formatDayLabel(DateTime(2026, 6, 20), now: now), '20 Jun');
    });

    test('a leap day is handled', () {
      expect(
        formatDayLabel(DateTime(2028, 2, 29), now: DateTime(2028, 2, 29, 9)),
        'Today',
      );
      expect(
        formatDayLabel(DateTime(2028, 2, 29), now: DateTime(2028, 3, 1, 9)),
        'Yesterday',
      );
    });
  });
}
