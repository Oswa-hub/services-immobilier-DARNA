import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/push_messaging.dart';
import '../../domain/repositories/notification_repository.dart';
import 'notification_providers.dart';

/// Override in tests with a fake.
final pushMessagingProvider = Provider<PushMessaging>((_) => FirebasePushMessaging());

final pushRegistrarProvider = Provider<PushRegistrar>((ref) {
  final registrar = PushRegistrar(
    messaging: ref.watch(pushMessagingProvider),
    repository: ref.watch(notificationRepositoryProvider),
  );
  ref.onDispose(registrar.dispose);
  return registrar;
});

/// Keeps `users/{uid}/devices/{token}` in step with who is signed in and the
/// "push" preference. Every method is safe to call repeatedly and never
/// throws: push is a bonus, the in-app center always works.
class PushRegistrar {
  PushRegistrar({required this.messaging, required this.repository});

  final PushMessaging messaging;
  final NotificationRepository repository;

  String? _userId;
  String? _token;
  StreamSubscription<String>? _refreshSub;

  /// The account this device is registered for, if any (tests / debug).
  String? get registeredUserId => _userId;
  String? get registeredToken => _token;

  Future<void> sync({required String? userId, required bool enabled}) async {
    if (!messaging.isSupported) return;
    try {
      // Another account, signed out, or push switched off: drop the old registration.
      if (_userId != null && (_userId != userId || !enabled)) await _drop();
      if (userId == null || !enabled) return;
      if (_userId == userId && _token != null) return; // already registered

      if (!await messaging.requestPermission()) return;
      final token = await messaging.getToken();
      if (token == null || token.isEmpty) return;

      await repository.registerDevice(userId: userId, token: token, platform: messaging.platformName);
      _userId = userId;
      _token = token;
      _refreshSub ??= messaging.onTokenRefresh.listen(_onTokenRefresh);
    } catch (e) {
      debugPrint('Push registration skipped: $e');
    }
  }

  /// Call BEFORE signing out, while the rules still let us delete the device doc.
  Future<void> unregister() => _drop();

  Future<void> _onTokenRefresh(String token) async {
    final userId = _userId;
    final old = _token;
    if (userId == null || token.isEmpty || token == old) return;
    try {
      await repository.registerDevice(userId: userId, token: token, platform: messaging.platformName);
      _token = token;
      if (old != null) await repository.unregisterDevice(userId: userId, token: old);
    } catch (e) {
      debugPrint('Push token refresh failed: $e');
    }
  }

  Future<void> _drop() async {
    final userId = _userId;
    final token = _token;
    _userId = null;
    _token = null;
    if (userId == null || token == null) return;
    try {
      await repository.unregisterDevice(userId: userId, token: token);
    } catch (e) {
      // Signed out already: the server removes the token when it is reused or dead.
      debugPrint('Push unregister skipped: $e');
    }
  }

  void dispose() => _refreshSub?.cancel();
}
