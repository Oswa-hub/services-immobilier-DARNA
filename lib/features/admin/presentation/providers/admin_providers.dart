import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/admin_failure.dart';
import '../../../auth/domain/entities/auth_user.dart';
import '../../../auth/providers/auth_provider.dart';
import '../../../properties/domain/entities/property.dart';
import '../../../settings/presentation/providers/platform_settings_providers.dart';
import '../../data/admin_repository.dart';
import '../../domain/admin_models.dart';
import '../../domain/admin_policy.dart';

/// Override in tests with a fake.
final adminRepositoryProvider = Provider<AdminRepository>(
  (ref) => FirestoreAdminRepository(ref.watch(firestoreProvider)),
);

/// Nothing is read for a non-admin (the rules would refuse it anyway).
bool _isAdmin(Ref ref) => ref.watch(currentUserProvider.select((u) => u?.isAdmin ?? false));

final adminKpisProvider = FutureProvider.autoDispose<AdminKpis>((ref) {
  if (!_isAdmin(ref)) return const AdminKpis();
  return ref.watch(adminRepositoryProvider).loadKpis();
});

final adminAnalyticsProvider = FutureProvider.autoDispose<AdminAnalytics>((ref) {
  if (!_isAdmin(ref)) throw const AdminFailure(AdminFailureType.permissionDenied);
  return ref.watch(adminRepositoryProvider).loadAnalytics();
});

/// Users, optionally filtered by status on the server.
final adminUsersProvider = StreamProvider.autoDispose.family<List<AdminUser>, AccountStatus?>((ref, status) {
  if (!_isAdmin(ref)) return Stream.value(const []);
  return ref.watch(adminRepositoryProvider).watchUsers(status: status);
});

/// Listings, optionally filtered by status on the server.
final adminPropertiesProvider = StreamProvider.autoDispose.family<List<Property>, PropertyStatus?>((ref, status) {
  if (!_isAdmin(ref)) return Stream.value(const []);
  return ref.watch(adminRepositoryProvider).watchProperties(status: status);
});

final adminAuditLogsProvider = StreamProvider.autoDispose<List<AuditEntry>>((ref) {
  if (!_isAdmin(ref)) return Stream.value(const []);
  return ref.watch(adminRepositoryProvider).watchAuditLogs();
});

final adminActionsProvider = Provider<AdminActions>(AdminActions.new);

/// Every admin action in one place. Returns null on success, or the failure
/// (French message) — never throws to the UI.
class AdminActions {
  AdminActions(this._ref);

  final Ref _ref;

  AdminRepository get _repo => _ref.read(adminRepositoryProvider);
  String? get _adminId {
    final u = _ref.read(currentUserProvider);
    return (u != null && u.isAdmin) ? u.id : null;
  }

  Future<AdminFailure?> _run(Future<void> Function(String adminId) action) async {
    final adminId = _adminId;
    if (adminId == null) return const AdminFailure(AdminFailureType.permissionDenied);
    try {
      await action(adminId);
      return null;
    } on AdminFailure catch (f) {
      return f;
    }
  }

  Future<AdminFailure?> setUserStatus(AdminUser user, UserAction action, {String? reason}) =>
      _run((id) => _repo.setUserStatus(user, action, adminId: id, reason: reason));

  Future<AdminFailure?> setUserRole(AdminUser user, UserRole role) =>
      _run((id) => _repo.setUserRole(user, role, adminId: id));

  Future<AdminFailure?> moderate(Property property, ModerationAction action, {String? reason}) {
    final settings = _ref.read(platformSettingsProvider);
    return _run((id) => _repo.moderate(
          property,
          action,
          adminId: id,
          reason: reason,
          expirationDays: settings.listingExpirationDays,
          // Spark plan: no Cloud Functions, so the admin app notifies the owner.
          notifyOwner: !settings.serverNotifications,
        ));
  }

  /// Returns (recipients, failure).
  Future<(int, AdminFailure?)> sendNotification({
    required Audience audience,
    required AdminNotificationType type,
    required String title,
    required String body,
  }) async {
    final adminId = _adminId;
    if (adminId == null) return (0, const AdminFailure(AdminFailureType.permissionDenied));
    if (audience is! SingleUser && !_ref.read(platformSettingsProvider).announcementsEnabled) {
      return (0, const AdminFailure(AdminFailureType.invalid, 'Les annonces sont désactivées dans les paramètres.'));
    }
    try {
      final n = await _repo.sendNotification(audience: audience, type: type, title: title, body: body, adminId: adminId);
      return (n, null);
    } on AdminFailure catch (f) {
      return (0, f);
    }
  }
}
