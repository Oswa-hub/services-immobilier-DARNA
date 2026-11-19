import 'package:flutter_test/flutter_test.dart';

import '../../../lib/features/messaging/domain/messaging_formatters.dart';

void main() {
  final now = DateTime(2026, 11, 13, 15, 30); // Friday

  group('formatConversationStamp', () {
    test('today shows the time', () {
      expect(formatConversationStamp(DateTime(2026, 11, 13, 9, 5), now: now), '09:05');
    });
    test('yesterday', () {
      expect(formatConversationStamp(DateTime(2026, 11, 12, 23, 59), now: now), 'Yesterday');
    });
    test('this week shows the weekday', () {
      expect(formatConversationStamp(DateTime(2026, 11, 10, 8), now: now), 'Tue');
    });
    test('older shows the date, with the year when it differs', () {
      expect(formatConversationStamp(DateTime(2026, 10, 2), now: now), '02 Oct');
      expect(formatConversationStamp(DateTime(2025, 10, 2), now: now), '02 Oct 2025');
    });
  });

  group('formatDayLabel', () {
    test('today, yesterday, older', () {
      expect(formatDayLabel(DateTime(2026, 11, 13, 1), now: now), 'Today');
      expect(formatDayLabel(DateTime(2026, 11, 12), now: now), 'Yesterday');
      expect(formatDayLabel(DateTime(2026, 11, 9), now: now), 'Mon 09 Nov');
    });
  });

  test('isSameDay ignores the time of day', () {
    expect(isSameDay(DateTime(2026, 11, 13, 0, 1), DateTime(2026, 11, 13, 23, 59)), isTrue);
    expect(isSameDay(DateTime(2026, 11, 13, 23, 59), DateTime(2026, 11, 14, 0, 1)), isFalse);
  });

  test('formatClock pads hours and minutes', () {
    expect(formatClock(DateTime(2026, 1, 1, 7, 3)), '07:03');
  });
}
