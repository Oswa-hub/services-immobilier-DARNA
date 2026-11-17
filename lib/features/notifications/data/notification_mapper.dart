import 'package:cloud_firestore/cloud_firestore.dart' show Timestamp;

import '../domain/entities/app_notification.dart';

/// Firestore map -> [AppNotification]. Defensive: a malformed document is
/// skipped (null), never crashes the notification center.
class NotificationMapper {
  NotificationMapper._();

  static AppNotification? tryFromMap(String id, Map<String, dynamic> d) {
    final title = _str(d['title']);
    final userId = _str(d['userId']);
    if (id.isEmpty || title == null || userId == null) return null;
    final data = d['data'];
    return AppNotification(
      id: id,
      userId: userId,
      type: NotificationType.parse(_str(d['type'])),
      title: title,
      body: _str(d['body']) ?? '',
      read: d['read'] == true,
      propertyId: _str(d['propertyId']),
      conversationId: _str(d['conversationId']),
      createdAt: _date(d['createdAt']),
      data: data is Map ? Map<String, dynamic>.from(data) : const {},
    );
  }

  static String? _str(Object? v) {
    if (v is! String) return null;
    final t = v.trim();
    return t.isEmpty ? null : t;
  }

  static DateTime? _date(Object? v) => switch (v) {
        Timestamp t => t.toDate(),
        DateTime d => d,
        int ms => DateTime.fromMillisecondsSinceEpoch(ms),
        _ => null,
      };
}
