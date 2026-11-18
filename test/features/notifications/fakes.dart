import 'dart:async';

import 'package:team_app/core/errors/notification_failure.dart';
import 'package:team_app/features/notifications/data/push_messaging.dart';
import 'package:team_app/features/notifications/domain/entities/app_notification.dart';
import 'package:team_app/features/notifications/domain/entities/notification_preferences.dart';
import 'package:team_app/features/notifications/domain/repositories/notification_repository.dart';

AppNotification makeNotification({
  String id = 'n1',
  String userId = 'u1',
  NotificationType type = NotificationType.listingApproved,
  String title = 'Annonce approuvée',
  String body = '« Villa » est maintenant en ligne.',
  bool read = false,
  String? propertyId = 'p1',
  String? conversationId,
  DateTime? createdAt,
}) =>
    AppNotification(
      id: id,
      userId: userId,
      type: type,
      title: title,
      body: body,
      read: read,
      propertyId: propertyId,
      conversationId: conversationId,
      createdAt: createdAt,
    );

/// In-memory repository: behaves like the Firestore one (live streams).
class FakeNotificationRepository implements NotificationRepository {
  FakeNotificationRepository([List<AppNotification> initial = const []]) : _items = [...initial];

  final List<AppNotification> _items; // newest first
  final _changes = StreamController<void>.broadcast();
  NotificationPreferences prefs = NotificationPreferences.defaults;

  bool failWrites = false;
  final List<String> calls = [];
  final Map<String, String> devices = {}; // token -> userId

  List<AppNotification> get items => List.unmodifiable(_items);

  void push(AppNotification n) {
    _items.insert(0, n);
    _changes.add(null);
  }

  void _check() {
    if (failWrites) throw const NotificationFailure(NotificationFailureType.network);
  }

  @override
  Stream<List<AppNotification>> watchNotifications(String userId, {int limit = 50}) async* {
    List<AppNotification> mine() => _items.where((n) => n.userId == userId).take(limit).toList();
    yield mine();
    await for (final _ in _changes.stream) {
      yield mine();
    }
  }

  @override
  Stream<int> watchUnreadCount(String userId, {int cap = 100}) async* {
    int count() => _items.where((n) => n.userId == userId && !n.read).length.clamp(0, cap);
    yield count();
    await for (final _ in _changes.stream) {
      yield count();
    }
  }

  @override
  Future<void> markRead(String notificationId) async {
    calls.add('markRead:$notificationId');
    _check();
    final i = _items.indexWhere((n) => n.id == notificationId);
    if (i >= 0) _items[i] = _items[i].copyWith(read: true);
    _changes.add(null);
  }

  @override
  Future<int> markAllRead(String userId) async {
    calls.add('markAllRead:$userId');
    _check();
    var changed = 0;
    for (var i = 0; i < _items.length; i++) {
      if (_items[i].userId == userId && !_items[i].read) {
        _items[i] = _items[i].copyWith(read: true);
        changed++;
      }
    }
    _changes.add(null);
    return changed;
  }

  @override
  Future<void> delete(String notificationId) async {
    calls.add('delete:$notificationId');
    _check();
    _items.removeWhere((n) => n.id == notificationId);
    _changes.add(null);
  }

  @override
  Future<NotificationPreferences> loadPreferences(String userId) async => prefs;

  @override
  Future<void> savePreferences(String userId, NotificationPreferences preferences) async {
    calls.add('savePreferences');
    _check();
    prefs = preferences;
  }

  @override
  Future<void> registerDevice({required String userId, required String token, required String platform}) async {
    calls.add('register:$userId:$token');
    _check();
    devices[token] = userId;
  }

  @override
  Future<void> unregisterDevice({required String userId, required String token}) async {
    calls.add('unregister:$userId:$token');
    _check();
    devices.remove(token);
  }
}

class FakePushMessaging implements PushMessaging {
  FakePushMessaging({this.isSupported = true, this.granted = true, this.token = 'tok-1'});

  @override
  bool isSupported;
  bool granted;
  String? token;
  int permissionRequests = 0;

  final refresh = StreamController<String>.broadcast();
  final taps = StreamController<Map<String, String>>.broadcast();
  Map<String, String>? initial;

  @override
  Future<bool> requestPermission() async {
    permissionRequests++;
    return granted;
  }

  @override
  Future<String?> getToken() async => token;

  @override
  Stream<String> get onTokenRefresh => refresh.stream;

  @override
  Future<Map<String, String>?> initialTapData() async => initial;

  @override
  Stream<Map<String, String>> get onTap => taps.stream;

  @override
  String get platformName => 'android';
}
