import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/admin_failure.dart';
import '../../../../core/errors/report_failure.dart';
import '../../../admin/domain/admin_policy.dart';
import '../../../admin/presentation/providers/admin_providers.dart';
import '../../../auth/providers/auth_provider.dart';
import '../../../settings/presentation/providers/platform_settings_providers.dart';
import '../../data/report_repository.dart';
import '../../domain/report.dart';

/// Override in tests with a fake.
final reportRepositoryProvider = Provider<ReportRepository>(
  (ref) => FirestoreReportRepository(ref.watch(firestoreProvider)),
);

String? _uid(Ref ref) => ref.watch(currentUserProvider.select((u) => u?.id));

/// My reports and their status (Profile > Mes signalements).
final myReportsProvider = StreamProvider.autoDispose<List<Report>>((ref) {
  final uid = _uid(ref);
  if (uid == null) return Stream.value(const []);
  return ref.watch(reportRepositoryProvider).watchMine(uid);
});

/// Users I blocked.
final blockedUsersProvider = StreamProvider<List<BlockedUser>>((ref) {
  final uid = _uid(ref);
  if (uid == null) return Stream.value(const []);
  return ref.watch(reportRepositoryProvider).watchBlocked(uid);
});

/// Did I block [otherId]? false while loading.
final isBlockedProvider = Provider.family<bool, String>(
  (ref, otherId) => ref.watch(blockedUsersProvider).maybeWhen(
        data: (list) => list.any((b) => b.id == otherId),
        orElse: () => false,
      ),
);

final reportActionsProvider = Provider<ReportActions>(ReportActions.new);

/// User actions. Return the failure (French message) or null — never throw.
class ReportActions {
  ReportActions(this._ref);
  final Ref _ref;

  ReportRepository get _repo => _ref.read(reportRepositoryProvider);
  String? get _me => _ref.read(currentUserProvider)?.id;

  Future<ReportFailure?> _run(Future<void> Function(String me) action) async {
    final me = _me;
    if (me == null) return const ReportFailure(ReportFailureType.permissionDenied);
    try {
      await action(me);
      return null;
    } on ReportFailure catch (f) {
      return f;
    }
  }

  Future<ReportFailure?> submit({
    required ReportTarget target,
    required String reasonId,
    required String reasonLabel,
    String description = '',
  }) =>
      _run((me) => _repo.submit(
            reporterId: me,
            target: target,
            reasonId: reasonId,
            reasonLabel: reasonLabel,
            description: description,
          ));

  Future<ReportFailure?> block(String otherId, String otherName) =>
      _run((me) => _repo.block(me: me, otherId: otherId, otherName: otherName));

  Future<ReportFailure?> unblock(String otherId) => _run((me) => _repo.unblock(me: me, otherId: otherId));
}

// ---- admin ----------------------------------------------------------------------------

final adminReportsProvider = StreamProvider.autoDispose.family<List<Report>, ReportStatus?>((ref, status) {
  final isAdmin = ref.watch(currentUserProvider.select((u) => u?.isAdmin ?? false));
  if (!isAdmin) return Stream.value(const []);
  return ref.watch(reportRepositoryProvider).watchAll(status: status);
});

final adminReportActionsProvider = Provider<AdminReportActions>(AdminReportActions.new);

/// Admin side of the lifecycle. A failure message is returned (String) or null.
class AdminReportActions {
  AdminReportActions(this._ref);
  final Ref _ref;

  ReportRepository get _repo => _ref.read(reportRepositoryProvider);

  String? get _adminId {
    final u = _ref.read(currentUserProvider);
    return (u != null && u.isAdmin) ? u.id : null;
  }

  Future<String?> _run(Future<void> Function(String adminId) action) async {
    final id = _adminId;
    if (id == null) return const ReportFailure(ReportFailureType.permissionDenied).message;
    try {
      await action(id);
      return null;
    } on ReportFailure catch (f) {
      return f.message;
    } on AdminFailure catch (f) {
      return f.message;
    }
  }

  Future<String?> assignToMe(Report r) => _run((id) => _repo.assign(r, adminId: id));

  Future<String?> startInvestigation(Report r) => _run((id) => _repo.startInvestigation(r, adminId: id));

  /// Applies [action] to the reported listing / account FIRST (audited by the
  /// admin repository), then closes the report. If the measure fails, the
  /// report stays open.
  Future<String?> close(Report r, {required ReportStatus to, required String note, ResolutionAction action = ResolutionAction.none}) =>
      _run((id) async {
        if (to == ReportStatus.resolved && action != ResolutionAction.none) {
          final failure = await _enforce(r, action, note);
          if (failure != null) throw failure;
        }
        await _repo.close(
          r,
          to: to,
          note: note,
          action: to == ReportStatus.resolved ? action : ResolutionAction.none,
          adminId: id,
          notifyReporter: !_ref.read(platformSettingsProvider).serverNotifications,
        );
      });

  Future<AdminFailure?> _enforce(Report r, ResolutionAction action, String note) async {
    final admin = _ref.read(adminRepositoryProvider);
    final actions = _ref.read(adminActionsProvider);
    final full = 'Signalement : ${note.trim()}';
    // AdminPolicy limits moderation reasons to 500 characters.
    final reason = full.length <= AdminPolicy.maxReasonLength ? full : '${full.substring(0, AdminPolicy.maxReasonLength - 1)}…';
    try {
      switch (action) {
        case ResolutionAction.listingSuspended || ResolutionAction.listingRemoved:
          final propertyId = r.target.propertyId;
          if (propertyId == null) {
            return const AdminFailure(AdminFailureType.invalid, 'Ce signalement ne concerne pas une annonce.');
          }
          final property = await admin.loadProperty(propertyId);
          if (property == null) return const AdminFailure(AdminFailureType.invalid, 'Annonce introuvable.');
          final move = action == ResolutionAction.listingSuspended ? ModerationAction.suspend : ModerationAction.remove;
          if (!move.from.contains(property.status)) {
            return AdminFailure(AdminFailureType.invalid, 'Impossible : l’annonce est déjà « ${property.status.wire} ».');
          }
          return await actions.moderate(property, move, reason: reason);
        case ResolutionAction.userSuspended || ResolutionAction.userBanned:
          final userId = r.target.ownerId;
          if (userId == null) return const AdminFailure(AdminFailureType.invalid, 'Compte concerné inconnu.');
          final user = await admin.loadUser(userId);
          if (user == null) return const AdminFailure(AdminFailureType.invalid, 'Utilisateur introuvable.');
          final move = action == ResolutionAction.userSuspended ? UserAction.suspend : UserAction.ban;
          if (user.status == move.target) return null; // already applied
          return await actions.setUserStatus(user, move, reason: reason);
        case ResolutionAction.none:
          return null;
      }
    } on AdminFailure catch (f) {
      return f;
    }
  }
}
