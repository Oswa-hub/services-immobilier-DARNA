const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
const _weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

String _two(int n) => n.toString().padLeft(2, '0');

/// Whole calendar days between [a] and [b] (a later than b => positive).
int _dayDiff(DateTime a, DateTime b) =>
    DateTime.utc(a.year, a.month, a.day).difference(DateTime.utc(b.year, b.month, b.day)).inDays;

bool isSameDay(DateTime a, DateTime b) {
  final x = a.toLocal(), y = b.toLocal();
  return _dayDiff(x, y) == 0;
}

/// `10:42`
String formatClock(DateTime d) {
  final l = d.toLocal();
  return '${_two(l.hour)}:${_two(l.minute)}';
}

/// Conversation list stamp: `10:42` today, `Yesterday`, weekday within the
/// last week, else `08 Nov` (with the year when it is not the current one).
String formatConversationStamp(DateTime d, {DateTime? now}) {
  final l = d.toLocal();
  final n = (now ?? DateTime.now()).toLocal();
  final diff = _dayDiff(n, l);
  if (diff <= 0) return formatClock(l);
  if (diff == 1) return 'Yesterday';
  if (diff < 7) return _weekdays[l.weekday - 1];
  final date = '${_two(l.day)} ${_months[l.month - 1]}';
  return l.year == n.year ? date : '$date ${l.year}';
}

/// Separator shown between days inside a conversation.
String formatDayLabel(DateTime d, {DateTime? now}) {
  final l = d.toLocal();
  final n = (now ?? DateTime.now()).toLocal();
  final diff = _dayDiff(n, l);
  if (diff <= 0) return 'Today';
  if (diff == 1) return 'Yesterday';
  final date = '${_weekdays[l.weekday - 1]} ${_two(l.day)} ${_months[l.month - 1]}';
  return l.year == n.year ? date : '$date ${l.year}';
}
