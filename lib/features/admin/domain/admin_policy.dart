import '../../auth/domain/entities/auth_user.dart';
import '../../properties/domain/entities/property.dart';
import 'admin_models.dart';

/// Account actions (spec §39). Pure; mirrored by the UI and audited.
enum UserAction {
  suspend('Suspendre', AccountStatus.suspended, needsReason: true),
  restore('Rétablir', AccountStatus.active),
  ban('Bannir', AccountStatus.banned, needsReason: true),
  delete('Supprimer le compte', AccountStatus.deleted, needsReason: true);

  const UserAction(this.label, this.target, {this.needsReason = false});

  final String label;
  final AccountStatus target;
  final bool needsReason;

  String get auditAction => 'user.$name';
}

/// Listing moderation (spec §40). [from] = statuses the action applies to.
enum ModerationAction {
  approve('Approuver', {PropertyStatus.pendingReview}, PropertyStatus.published),
  reject('Refuser', {PropertyStatus.pendingReview}, PropertyStatus.rejected, needsReason: true),
  suspend('Suspendre', {PropertyStatus.published}, PropertyStatus.suspended, needsReason: true),
  restore('Rétablir', {PropertyStatus.suspended}, PropertyStatus.published),
  remove(
    'Retirer',
    {PropertyStatus.pendingReview, PropertyStatus.published, PropertyStatus.suspended, PropertyStatus.expired},
    PropertyStatus.removed,
    needsReason: true,
  );

  const ModerationAction(this.label, this.from, this.to, {this.needsReason = false});

  final String label;
  final Set<PropertyStatus> from;
  final PropertyStatus to;
  final bool needsReason;

  String get auditAction => 'property.$name';
}

class AdminPolicy {
  AdminPolicy._();

  /// An admin never acts on their own account (no self-lockout), and only
  /// moves that change something are offered.
  static List<UserAction> userActions(AdminUser target, {required String actorId}) {
    if (target.id == actorId) return const [];
    return [
      for (final a in UserAction.values)
        if (a.target != target.status) a,
    ];
  }

  static bool canChangeRole(AdminUser target, {required String actorId}) =>
      target.id != actorId && target.status != AccountStatus.deleted;

  static List<ModerationAction> moderationActions(PropertyStatus status) => [
        for (final a in ModerationAction.values)
          if (a.from.contains(status)) a,
      ];

  static const minReasonLength = 5;
  static const maxReasonLength = 500;

  /// French error, or null when [reason] is acceptable for an action that needs one.
  static String? checkReason(String? reason) {
    final r = reason?.trim() ?? '';
    if (r.length < minReasonLength) return 'Indiquez un motif ($minReasonLength caractères minimum).';
    if (r.length > maxReasonLength) return 'Motif trop long ($maxReasonLength caractères maximum).';
    return null;
  }

  /// Expiry of a listing approved [now], from the platform setting.
  static DateTime expiryFor(DateTime now, int expirationDays) => now.add(Duration(days: expirationDays));

  // ---- notification texts sent to the owner (French) ---------------------------------

  static ({String type, String title, String body})? ownerNotice(
    ModerationAction action,
    String listingTitle, {
    String? reason,
  }) {
    final t = listingTitle.trim().isEmpty ? 'Votre annonce' : '« ${listingTitle.trim()} »';
    final r = reason?.trim() ?? '';
    return switch (action) {
      ModerationAction.approve => (type: 'listingApproved', title: 'Annonce approuvée', body: '$t est maintenant en ligne.'),
      ModerationAction.reject => (
          type: 'listingRejected',
          title: 'Annonce refusée',
          body: r.isEmpty ? '$t a été refusée.' : '$t a été refusée : $r',
        ),
      ModerationAction.suspend => (
          type: 'listingSuspended',
          title: 'Annonce suspendue',
          body: r.isEmpty ? '$t a été suspendue.' : '$t a été suspendue : $r',
        ),
      ModerationAction.restore => (type: 'listingRestored', title: 'Annonce rétablie', body: '$t est de nouveau en ligne.'),
      ModerationAction.remove => null, // the owner sees it in My Listings
    };
  }
}
