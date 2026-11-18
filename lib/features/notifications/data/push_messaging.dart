import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

/// Push transport (FCM) behind an interface so the registration logic is
/// unit-tested with a fake and the app still runs where push is unavailable.
abstract class PushMessaging {
  /// Push works on Android / iOS / macOS. Web needs a service worker + VAPID
  /// key (not configured yet), desktop has no FCM: there we rely on the
  /// in-app center only.
  bool get isSupported;

  /// Asks the OS permission (Android 13+, iOS). True when granted (or provisional).
  Future<bool> requestPermission();

  Future<String?> getToken();
  Stream<String> get onTokenRefresh;

  /// `data` of the push that cold-started the app by a tap, if any.
  Future<Map<String, String>?> initialTapData();

  /// `data` of pushes tapped while the app was in background.
  Stream<Map<String, String>> get onTap;

  String get platformName;
}

class FirebasePushMessaging implements PushMessaging {
  FirebasePushMessaging([FirebaseMessaging? messaging]) : _fm = messaging;

  // Lazy: FirebaseMessaging.instance must not be touched where unsupported.
  final FirebaseMessaging? _fm;
  FirebaseMessaging get _m => _fm ?? FirebaseMessaging.instance;

  static Map<String, String> _data(RemoteMessage m) =>
      {for (final e in m.data.entries) e.key: '${e.value}'};

  @override
  bool get isSupported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.macOS);

  @override
  String get platformName => kIsWeb ? 'web' : defaultTargetPlatform.name.toLowerCase();

  @override
  Future<bool> requestPermission() async {
    final settings = await _m.requestPermission();
    // Apple only: show banners for pushes received while the app is open.
    if (defaultTargetPlatform == TargetPlatform.iOS || defaultTargetPlatform == TargetPlatform.macOS) {
      await _m.setForegroundNotificationPresentationOptions(alert: true, badge: true, sound: true);
    }
    return settings.authorizationStatus == AuthorizationStatus.authorized ||
        settings.authorizationStatus == AuthorizationStatus.provisional;
  }

  @override
  Future<String?> getToken() => _m.getToken();

  @override
  Stream<String> get onTokenRefresh => _m.onTokenRefresh;

  @override
  Future<Map<String, String>?> initialTapData() async {
    final m = await _m.getInitialMessage();
    return m == null ? null : _data(m);
  }

  @override
  Stream<Map<String, String>> get onTap => FirebaseMessaging.onMessageOpenedApp.map(_data);
}
