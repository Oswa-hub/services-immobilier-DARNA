import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart' show FirebaseException;
import 'package:flutter/foundation.dart';

import '../../../core/errors/notification_failure.dart';
import '../domain/entities/app_notification.dart';
import '../domain/entities/notification_preferences.dart';
import '../domain/repositories/notification_repository.dart';
import 'notification_mapper.dart';
import 'notification_remote_data_source.dart';

class NotificationRepositoryImpl implements NotificationRepository {
  NotificationRepositoryImpl(this._remote);

  final NotificationRemoteDataSource _remote;

  static NotificationFailure _map(Object e) {
    if (e is NotificationFailure) return e;
    if (e is FirebaseException) {
      debugPrint('Notifications failed [${e.code}]: ${e.message}');
      return NotificationFailure(switch (e.code) {
        'permission-denied' || 'unauthenticated' => NotificationFailureType.permissionDenied,
        'unavailable' || 'deadline-exceeded' || 'network-request-failed' => NotificationFailureType.network,
        'failed-precondition' => NotificationFailureType.indexMissing,
        _ => NotificationFailureType.unknown,
      });
    }
    debugPrint('Unexpected notifications error: $e');
    return const NotificationFailure(NotificationFailureType.unknown);
  }

  Future<T> _guard<T>(Future<T> Function() run) async {
    try {
      return await run();
    } catch (e) {
      throw _map(e);
    }
  }

  /// Errors thrown while opening AND errors emitted later by the snapshot
  /// listener both become [NotificationFailure].
  Stream<T> _guardStream<T>(Stream<T> Function() open) {
    final Stream<T> source;
    try {
      source = open();
    } catch (e) {
      return Stream<T>.error(_map(e));
    }
    return source.transform(
      StreamTransformer<T, T>.fromHandlers(handleError: (e, st, sink) => sink.addError(_map(e), st)),
    );
  }

  static void _checkId(String id) {
    if (id.trim().isEmpty || id.contains('/')) {
      throw const NotificationFailure(NotificationFailureType.unknown);
    }
  }

  @override
  Stream<List<AppNotification>> watchNotifications(String userId, {int limit = 50}) => _guardStream(() {
        _checkId(userId);
        return _remote.watchForUser(userId, limit: limit).map((docs) => [
              for (final d in docs) ?NotificationMapper.tryFromMap(d.id, d.data),
            ]);
      });

  @override
  Stream<int> watchUnreadCount(String userId, {int cap = 100}) => _guardStream(() {
        _checkId(userId);
        return _remote.watchUnreadCount(userId, cap: cap);
      });

  @override
  Future<void> markRead(String notificationId) => _guard(() async {
        _checkId(notificationId);
        await _remote.markRead(notificationId);
      });

  @override
  Future<int> markAllRead(String userId) => _guard(() async {
        _checkId(userId);
        return _remote.markAllRead(userId);
      });

  @override
  Future<void> delete(String notificationId) => _guard(() async {
        _checkId(notificationId);
        await _remote.delete(notificationId);
      });

  @override
  Future<NotificationPreferences> loadPreferences(String userId) => _guard(() async {
        _checkId(userId);
        return NotificationPreferences.fromMap(await _remote.readPreferences(userId));
      });

  @override
  Future<void> savePreferences(String userId, NotificationPreferences preferences) => _guard(() async {
        _checkId(userId);
        await _remote.writePreferences(userId, preferences.toMap());
      });

  @override
  Future<void> registerDevice({required String userId, required String token, required String platform}) =>
      _guard(() async {
        _checkId(userId);
        _checkId(token);
        await _remote.upsertDevice(userId: userId, token: token, platform: platform);
      });

  @override
  Future<void> unregisterDevice({required String userId, required String token}) => _guard(() async {
        _checkId(userId);
        _checkId(token);
        await _remote.deleteDevice(userId: userId, token: token);
      });
}
