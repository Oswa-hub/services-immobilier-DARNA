import 'package:cloud_firestore/cloud_firestore.dart' show Timestamp;

/// Module 14 — Reports & Safety (spec §36, §41).
///
/// `reports/{reporterId}_{targetType}_{targetId}`: one report per reporter and
/// target (a second attempt is refused by the rules), so nobody can flood the
/// queue by tapping "Signaler" ten times.

enum ReportTargetType {
  property('Annonce'),
  user('Utilisateur'),
  agent('Agent'),
  message('Message');

  const ReportTargetType(this.label);
  final String label;

  static ReportTargetType? tryParse(Object? v) {
    for (final t in values) {
      if (t.name == v) return t;
    }
    return null;
  }
}

/// open → investigating → resolved | rejected (spec §36 state diagram).
enum ReportStatus {
  open('Ouvert'),
  investigating('En cours d’examen'),
  resolved('Résolu'),
  rejected('Rejeté');

  const ReportStatus(this.label);
  final String label;

  bool get isClosed => this == resolved || this == rejected;

  static ReportStatus parse(Object? v) => values.firstWhere((s) => s.name == v, orElse: () => open);
}

enum ReportPriority {
  high('Élevée'),
  medium('Moyenne'),
  low('Faible');

  const ReportPriority(this.label);
  final String label;

  static ReportPriority parse(Object? v) => values.firstWhere((p) => p.name == v, orElse: () => medium);
}

/// What an admin did about a resolved report (recorded with the resolution).
enum ResolutionAction {
  none('Aucune mesure'),
  listingSuspended('Annonce suspendue'),
  listingRemoved('Annonce retirée'),
  userSuspended('Compte suspendu'),
  userBanned('Compte banni');

  const ResolutionAction(this.label);
  final String label;

  static ResolutionAction parse(Object? v) => values.firstWhere((a) => a.name == v, orElse: () => none);
}

/// What is being reported. [ownerId] = the account responsible for it (owner
/// of the listing, author of the message, the user/agent themselves): the
/// admin may act on that account.
class ReportTarget {
  const ReportTarget({
    required this.type,
    required this.id,
    required this.label,
    this.ownerId,
    this.conversationId,
    this.propertyId,
  });

  final ReportTargetType type;
  final String id;

  /// Snapshot shown to the admin (listing title, user name, message excerpt).
  final String label;
  final String? ownerId;
  final String? conversationId;
  final String? propertyId;

  factory ReportTarget.property({required String id, required String title, required String ownerId}) =>
      ReportTarget(type: ReportTargetType.property, id: id, label: title, ownerId: ownerId, propertyId: id);

  factory ReportTarget.user({required String id, required String name, bool agent = false, String? conversationId}) =>
      ReportTarget(
        type: agent ? ReportTargetType.agent : ReportTargetType.user,
        id: id,
        label: name,
        ownerId: id,
        conversationId: conversationId,
      );

  factory ReportTarget.message({
    required String messageId,
    required String conversationId,
    required String senderId,
    required String text,
    String? propertyId,
  }) =>
      ReportTarget(
        type: ReportTargetType.message,
        id: messageId,
        label: text.length > 200 ? '${text.substring(0, 199)}…' : text,
        ownerId: senderId,
        conversationId: conversationId,
        propertyId: propertyId,
      );

  /// Document id: one report per reporter and target.
  String reportIdFor(String reporterId) => '${reporterId}_${type.name}_$id';
}

class Report {
  const Report({
    required this.id,
    required this.reporterId,
    required this.target,
    required this.reason,
    required this.reasonLabel,
    required this.status,
    required this.priority,
    this.description = '',
    this.assignedTo,
    this.resolution,
    this.resolutionAction = ResolutionAction.none,
    this.createdAt,
    this.updatedAt,
    this.closedAt,
    this.closedBy,
  });

  final String id;
  final String reporterId;
  final ReportTarget target;

  /// Reason id (catalog `report_reasons`) and its label at report time.
  final String reason;
  final String reasonLabel;
  final String description;
  final ReportStatus status;
  final ReportPriority priority;
  final String? assignedTo;

  /// Admin note shown to the reporter once closed.
  final String? resolution;
  final ResolutionAction resolutionAction;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? closedAt;
  final String? closedBy;

  static DateTime? _date(Object? v) => switch (v) {
        Timestamp t => t.toDate(),
        DateTime d => d,
        _ => null,
      };

  static Report? tryFromMap(String id, Map<String, dynamic> d) {
    String? str(String k) => d[k] is String && (d[k] as String).isNotEmpty ? d[k] as String : null;
    final type = ReportTargetType.tryParse(d['targetType']);
    final reporterId = str('reporterId');
    final targetId = str('targetId');
    final reason = str('reason');
    if (type == null || reporterId == null || targetId == null || reason == null) return null;
    return Report(
      id: id,
      reporterId: reporterId,
      target: ReportTarget(
        type: type,
        id: targetId,
        label: str('targetLabel') ?? '',
        ownerId: str('targetOwnerId'),
        conversationId: str('conversationId'),
        propertyId: str('propertyId'),
      ),
      reason: reason,
      reasonLabel: str('reasonLabel') ?? reason,
      description: str('description') ?? '',
      status: ReportStatus.parse(d['status']),
      priority: ReportPriority.parse(d['priority']),
      assignedTo: str('assignedTo'),
      resolution: str('resolution'),
      resolutionAction: ResolutionAction.parse(d['resolutionAction']),
      createdAt: _date(d['createdAt']),
      updatedAt: _date(d['updatedAt']),
      closedAt: _date(d['closedAt']),
      closedBy: str('closedBy'),
    );
  }
}

/// Pure rules, mirrored by firestore.rules. Unit-tested.
class ReportPolicy {
  ReportPolicy._();

  static const maxDescription = 1000;
  static const minResolution = 5;
  static const maxResolution = 1000;

  /// Reasons that put people's money or safety at risk (catalog slugs).
  static const _highRisk = {'fraude', 'arnaque', 'fausse_annonce'};
  static const _mediumRisk = {'activite_suspecte', 'contenu_offensant', 'informations_incorrectes'};

  /// Spec §41: high-risk reports first. Suspicious activity by a person (user,
  /// agent, message) is treated as high risk too.
  static ReportPriority priorityFor(String reason, ReportTargetType type) {
    if (_highRisk.contains(reason)) return ReportPriority.high;
    if (reason == 'activite_suspecte' && type != ReportTargetType.property) return ReportPriority.high;
    if (_mediumRisk.contains(reason)) return ReportPriority.medium;
    return ReportPriority.low;
  }

  /// Several people reporting the same target raises its priority.
  static ReportPriority escalate(ReportPriority base, int reportsOnTarget) {
    if (reportsOnTarget >= 3) return ReportPriority.high;
    if (reportsOnTarget == 2 && base == ReportPriority.low) return ReportPriority.medium;
    return base;
  }

  static bool canTransition(ReportStatus from, ReportStatus to) => switch ((from, to)) {
        (ReportStatus.open, ReportStatus.investigating) => true,
        (ReportStatus.investigating, ReportStatus.resolved) => true,
        (ReportStatus.investigating, ReportStatus.rejected) => true,
        _ => false,
      };

  /// French error or null.
  static String? checkSubmission({
    required String reporterId,
    required ReportTarget target,
    required String? reason,
    required String description,
  }) {
    if (reason == null || reason.isEmpty) return 'Choisissez un motif.';
    if (target.id.isEmpty || target.id.contains('/')) return 'Élément introuvable.';
    if (target.id == reporterId || target.ownerId == reporterId) return 'Vous ne pouvez pas vous signaler vous-même.';
    if (description.trim().length > maxDescription) return 'Description trop longue ($maxDescription caractères max).';
    if (reason == 'autre' && description.trim().length < 10) return 'Précisez le problème (10 caractères minimum).';
    return null;
  }

  static String? checkResolution(String note) {
    final n = note.trim();
    if (n.length < minResolution) return 'Expliquez la décision ($minResolution caractères minimum).';
    if (n.length > maxResolution) return 'Texte trop long ($maxResolution caractères max).';
    return null;
  }

  /// Sort: open work first, then priority, then oldest first (fair queue).
  static int compareForQueue(Report a, Report b, {Map<String, int> countByTarget = const {}}) {
    int rank(Report r) => r.status.isClosed ? 1 : 0;
    if (rank(a) != rank(b)) return rank(a) - rank(b);
    final pa = escalate(a.priority, countByTarget[targetKey(a)] ?? 1).index;
    final pb = escalate(b.priority, countByTarget[targetKey(b)] ?? 1).index;
    if (pa != pb) return pa - pb;
    final da = a.createdAt ?? DateTime(9999);
    final db = b.createdAt ?? DateTime(9999);
    return da.compareTo(db);
  }

  static String targetKey(Report r) => '${r.target.type.name}:${r.target.id}';

  static Map<String, int> countByTarget(Iterable<Report> reports) {
    final m = <String, int>{};
    for (final r in reports) {
      final k = targetKey(r);
      m[k] = (m[k] ?? 0) + 1;
    }
    return m;
  }
}
