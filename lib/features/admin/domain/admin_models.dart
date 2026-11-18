import 'package:cloud_firestore/cloud_firestore.dart' show Timestamp;

import '../../auth/domain/entities/auth_user.dart';

DateTime? readDate(Object? v) => switch (v) {
      Timestamp t => t.toDate(),
      DateTime d => d,
      _ => null,
    };

/// A row of `users/{id}` as the admin sees it.
class AdminUser {
  const AdminUser({
    required this.id,
    required this.email,
    this.name,
    this.phone,
    this.role = UserRole.user,
    this.status = AccountStatus.active,
    this.verified = false,
    this.createdAt,
    this.statusReason,
  });

  final String id;
  final String email;
  final String? name;
  final String? phone;
  final UserRole role;
  final AccountStatus status;
  final bool verified;
  final DateTime? createdAt;
  final String? statusReason;

  String get displayName => (name != null && name!.trim().isNotEmpty) ? name!.trim() : email;

  static AdminUser? tryFromMap(String id, Map<String, dynamic> d) {
    final email = d['email'];
    if (id.isEmpty || email is! String) return null;
    String? str(String k) => d[k] is String && (d[k] as String).trim().isNotEmpty ? (d[k] as String).trim() : null;
    return AdminUser(
      id: id,
      email: email,
      name: str('name'),
      phone: str('phone'),
      role: UserRole.parse(str('role')),
      status: AccountStatus.parse(str('status')),
      verified: d['verified'] == true,
      createdAt: readDate(d['createdAt']),
      statusReason: str('statusReason'),
    );
  }
}

/// Dashboard numbers (spec §38). A null value = could not be counted
/// (e.g. the collection is not readable yet): shown as "—".
class AdminKpis {
  const AdminKpis({
    this.totalUsers,
    this.activeUsers,
    this.newUsers7d,
    this.totalProperties,
    this.publishedProperties,
    this.pendingListings,
    this.pendingVerifications,
    this.openReports,
  });

  final int? totalUsers;
  final int? activeUsers;
  final int? newUsers7d;
  final int? totalProperties;
  final int? publishedProperties;
  final int? pendingListings;
  final int? pendingVerifications;
  final int? openReports;
}

/// `audit_logs/{id}` (same shape as Module 13 entries).
class AuditEntry {
  const AuditEntry({
    required this.id,
    required this.action,
    this.actorId,
    this.actorRole,
    this.targetType,
    this.targetId,
    this.previousStatus,
    this.newStatus,
    this.reason,
    this.timestamp,
  });

  final String id;
  final String action;
  final String? actorId;
  final String? actorRole;
  final String? targetType;
  final String? targetId;
  final String? previousStatus;
  final String? newStatus;
  final String? reason;
  final DateTime? timestamp;

  static AuditEntry? tryFromMap(String id, Map<String, dynamic> d) {
    final action = d['action'];
    if (action is! String || action.isEmpty) return null;
    String? str(String k) => d[k] is String ? d[k] as String : null;
    return AuditEntry(
      id: id,
      action: action,
      // Cloud Functions (Module 12) write `adminId`; app writes use `actorId`.
      actorId: str('actorId') ?? str('adminId'),
      actorRole: str('actorRole'),
      targetType: str('targetType'),
      targetId: str('targetId'),
      previousStatus: str('previousStatus'),
      newStatus: str('newStatus'),
      reason: str('reason'),
      timestamp: readDate(d['timestamp']),
    );
  }
}

/// Who receives an admin notification.
sealed class Audience {
  const Audience();
}

class AllUsers extends Audience {
  const AllUsers();
}

class UsersWithRole extends Audience {
  const UsersWithRole(this.role);
  final UserRole role;
}

class SingleUser extends Audience {
  const SingleUser(this.userId);
  final String userId;
}

enum AdminNotificationType {
  announcement('platformAnnouncement', 'Annonce de la plateforme'),
  warning('accountWarning', 'Avertissement de compte');

  const AdminNotificationType(this.wire, this.label);
  final String wire;
  final String label;
}

/// Spec §42 numbers, computed from the latest documents.
class AdminAnalytics {
  const AdminAnalytics({
    required this.sampledProperties,
    required this.sampledUsers,
    required this.byGovernorate,
    required this.byType,
    required this.byStatus,
    required this.averagePrice,
    required this.listingGrowth,
    required this.userGrowth,
    required this.totalViews,
    required this.totalFavorites,
  });

  final int sampledProperties;
  final int sampledUsers;

  /// Published listings, most frequent first.
  final List<MapEntry<String, int>> byGovernorate;
  final List<MapEntry<String, int>> byType;
  final List<MapEntry<String, int>> byStatus;

  /// Published listings: average price per transaction ('buy' / 'rent').
  final Map<String, double> averagePrice;

  /// Last 6 months, oldest first: ('2026-06', count).
  final List<MapEntry<String, int>> listingGrowth;
  final List<MapEntry<String, int>> userGrowth;

  final int totalViews;
  final int totalFavorites;
}
