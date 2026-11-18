import '../entities/app_notification.dart';

/// Date sections of the notification center.
enum NotificationSection {
  today('Aujourd’hui'),
  yesterday('Hier'),
  thisWeek('Cette semaine'),
  older('Plus anciennes');

  const NotificationSection(this.label);
  final String label;
}

class NotificationGroup {
  const NotificationGroup(this.section, this.items);
  final NotificationSection section;
  final List<AppNotification> items;
}

NotificationSection sectionFor(DateTime? createdAt, DateTime now) {
  // Pending server timestamp = it was just created.
  if (createdAt == null) return NotificationSection.today;
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(createdAt.year, createdAt.month, createdAt.day);
  final days = today.difference(day).inDays;
  if (days <= 0) return NotificationSection.today;
  if (days == 1) return NotificationSection.yesterday;
  if (days < 7) return NotificationSection.thisWeek;
  return NotificationSection.older;
}

/// Groups an already newest-first list into ordered, non-empty sections.
List<NotificationGroup> groupNotifications(List<AppNotification> items, {DateTime? now}) {
  final clock = now ?? DateTime.now();
  final buckets = <NotificationSection, List<AppNotification>>{};
  for (final n in items) {
    buckets.putIfAbsent(sectionFor(n.createdAt, clock), () => []).add(n);
  }
  return [
    for (final s in NotificationSection.values)
      if (buckets[s] != null) NotificationGroup(s, buckets[s]!),
  ];
}

/// "À l’instant", "il y a 5 min", "il y a 3 h", "hier", "12/03/2026".
String formatNotificationTime(DateTime? createdAt, {DateTime? now}) {
  if (createdAt == null) return 'À l’instant';
  final clock = now ?? DateTime.now();
  final diff = clock.difference(createdAt);
  if (diff.inMinutes < 1) return 'À l’instant';
  if (diff.inMinutes < 60) return 'il y a ${diff.inMinutes} min';
  if (diff.inHours < 24 && sectionFor(createdAt, clock) == NotificationSection.today) {
    return 'il y a ${diff.inHours} h';
  }
  if (sectionFor(createdAt, clock) == NotificationSection.yesterday) return 'Hier';
  String two(int v) => v.toString().padLeft(2, '0');
  return '${two(createdAt.day)}/${two(createdAt.month)}/${createdAt.year}';
}

/// Badge text: 0 -> null (no badge), 1..99 -> "n", more -> "99+".
String? unreadBadgeLabel(int count) {
  if (count <= 0) return null;
  return count > 99 ? '99+' : '$count';
}
