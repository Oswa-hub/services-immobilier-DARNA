import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/auth/providers/auth_provider.dart';
import '../features/notifications/domain/entities/app_notification.dart';
import '../features/notifications/domain/services/notification_navigation.dart';
import '../features/notifications/presentation/providers/notification_providers.dart';
import '../features/notifications/presentation/providers/push_registration.dart';
import 'router.dart';
import 'routes.dart';

/// Module 12 glue, watched once by [ImmoFindApp]:
///  * registers this device for push when a user is signed in and wants push;
///  * opens the right page when a push is tapped (cold start or background)
///    and marks that notification read.
final notificationBootstrapProvider = Provider<void>((ref) {
  final registrar = ref.watch(pushRegistrarProvider);
  final messaging = ref.watch(pushMessagingProvider);

  void syncRegistration() {
    final userId = ref.read(currentUserProvider)?.id;
    final enabled = ref.read(notificationPreferencesProvider).value?.pushNotifications ?? false;
    registrar.sync(userId: userId, enabled: enabled);
  }

  ref.listen(currentUserProvider.select((u) => u?.id), (_, _) => syncRegistration());
  ref.listen(
    notificationPreferencesProvider.select((p) => p.value?.pushNotifications),
    (_, _) => syncRegistration(),
    fireImmediately: true,
  );

  if (!messaging.isSupported) return;

  // A tapped push waits until a user is signed in (the router would send a
  // guest back to the login page and lose the target).
  Map<String, String>? pending;

  void open(Map<String, String> data) {
    if (ref.read(currentUserProvider) == null) {
      pending = data;
      return;
    }
    pending = null;
    final id = data['notificationId'];
    if (id != null && id.isNotEmpty) ref.read(notificationActionsProvider).markRead(id);
    final route = routeForNotification(
      type: NotificationType.parse(data['type']),
      propertyId: data['propertyId'],
      conversationId: data['conversationId'],
    );
    ref.read(routerProvider).push(route ?? Routes.notifications);
  }

  ref.listen(currentUserProvider.select((u) => u?.id), (_, userId) {
    final waiting = pending;
    // Let the router finish its own sign-in redirect (splash -> home) first.
    if (userId != null && waiting != null) {
      Future<void>.delayed(const Duration(milliseconds: 600), () => open(waiting));
    }
  });

  final sub = messaging.onTap.listen(open, onError: (Object e) => debugPrint('Push tap error: $e'));
  ref.onDispose(sub.cancel);

  messaging.initialTapData().then((data) {
    if (data != null) open(data);
  }).catchError((Object e) {
    debugPrint('Push initial message error: $e');
  });
});
