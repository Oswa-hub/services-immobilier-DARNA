// Module 14 — Reports & Safety: policy, providers, report sheet, admin closing.
// Run: flutter test test/features/reports
import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart' show Timestamp;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:team_app/core/errors/report_failure.dart';
import 'package:team_app/features/admin/domain/admin_models.dart';
import 'package:team_app/features/admin/presentation/providers/admin_providers.dart';
import 'package:team_app/features/auth/domain/entities/auth_user.dart';
import 'package:team_app/features/auth/providers/auth_provider.dart';
import 'package:team_app/features/content/presentation/providers/catalog_providers.dart';
import 'package:team_app/features/properties/domain/entities/property.dart';
import 'package:team_app/features/reports/data/report_repository.dart';
import 'package:team_app/features/reports/domain/report.dart';
import 'package:team_app/features/reports/presentation/providers/report_providers.dart';
import 'package:team_app/features/reports/presentation/widgets/report_sheet.dart';
import 'package:team_app/features/settings/domain/platform_settings.dart';
import 'package:team_app/features/settings/presentation/providers/platform_settings_providers.dart';

import '../../support_properties.dart';
import '../admin/admin_providers_test.dart' show FakeAdminRepository, FakeCatalogRepository;

const _me = AuthUser(id: 'u1', email: 'u1@x.tn', emailVerified: true);
const _admin = AuthUser(id: 'admin', email: 'a@x.tn', role: UserRole.admin, emailVerified: true);

final _propertyTarget = ReportTarget.property(id: 'p1', title: 'Villa La Marsa', ownerId: 'owner');

Report _report({
  String id = 'r1',
  ReportStatus status = ReportStatus.investigating,
  ReportPriority priority = ReportPriority.medium,
  ReportTarget? target,
  DateTime? createdAt,
}) =>
    Report(
      id: id,
      reporterId: 'u1',
      target: target ?? _propertyTarget,
      reason: 'fraude',
      reasonLabel: 'Fraude',
      status: status,
      priority: priority,
      createdAt: createdAt,
    );

class FakeReportRepository implements ReportRepository {
  final submitted = <String>[];
  final calls = <String>[];
  final blocked = <String, String>{};
  final _blockedChanges = StreamController<void>.broadcast();
  ReportFailure? failWith;

  @override
  Future<void> submit({
    required String reporterId,
    required ReportTarget target,
    required String reasonId,
    required String reasonLabel,
    required String description,
  }) async {
    if (failWith != null) throw failWith!;
    final id = target.reportIdFor(reporterId);
    if (submitted.contains(id)) throw const ReportFailure(ReportFailureType.duplicate);
    submitted.add(id);
  }

  @override
  Stream<List<Report>> watchMine(String reporterId) => Stream.value(const []);

  @override
  Future<void> block({required String me, required String otherId, required String otherName}) async {
    blocked[otherId] = otherName;
    _blockedChanges.add(null);
  }

  @override
  Future<void> unblock({required String me, required String otherId}) async {
    blocked.remove(otherId);
    _blockedChanges.add(null);
  }

  @override
  Stream<List<BlockedUser>> watchBlocked(String me) async* {
    List<BlockedUser> now() => [for (final e in blocked.entries) (id: e.key, name: e.value, since: null)];
    yield now();
    await for (final _ in _blockedChanges.stream) {
      yield now();
    }
  }

  @override
  Stream<List<Report>> watchAll({ReportStatus? status, int limit = 300}) => Stream.value(const []);

  @override
  Future<void> assign(Report report, {required String adminId}) async => calls.add('assign:${report.id}');

  @override
  Future<void> startInvestigation(Report report, {required String adminId}) async => calls.add('investigate:${report.id}');

  @override
  Future<void> close(Report report,
      {required ReportStatus to,
      required String note,
      required ResolutionAction action,
      required String adminId,
      required bool notifyReporter}) async {
    calls.add('close:${report.id}:${to.name}:${action.name}:$notifyReporter');
  }
}

void main() {
  group('ReportPolicy', () {
    test('priority from reason and target', () {
      expect(ReportPolicy.priorityFor('fraude', ReportTargetType.property), ReportPriority.high);
      expect(ReportPolicy.priorityFor('arnaque', ReportTargetType.user), ReportPriority.high);
      expect(ReportPolicy.priorityFor('activite_suspecte', ReportTargetType.agent), ReportPriority.high);
      expect(ReportPolicy.priorityFor('activite_suspecte', ReportTargetType.property), ReportPriority.medium);
      expect(ReportPolicy.priorityFor('contenu_offensant', ReportTargetType.message), ReportPriority.medium);
      expect(ReportPolicy.priorityFor('annonce_en_double', ReportTargetType.property), ReportPriority.low);
      expect(ReportPolicy.priorityFor('motif_ajoute_par_admin', ReportTargetType.property), ReportPriority.low);
    });

    test('several reports on one target escalate', () {
      expect(ReportPolicy.escalate(ReportPriority.low, 1), ReportPriority.low);
      expect(ReportPolicy.escalate(ReportPriority.low, 2), ReportPriority.medium);
      expect(ReportPolicy.escalate(ReportPriority.low, 3), ReportPriority.high);
      expect(ReportPolicy.escalate(ReportPriority.medium, 2), ReportPriority.medium);
    });

    test('lifecycle open -> investigating -> resolved | rejected', () {
      expect(ReportPolicy.canTransition(ReportStatus.open, ReportStatus.investigating), isTrue);
      expect(ReportPolicy.canTransition(ReportStatus.investigating, ReportStatus.resolved), isTrue);
      expect(ReportPolicy.canTransition(ReportStatus.investigating, ReportStatus.rejected), isTrue);
      expect(ReportPolicy.canTransition(ReportStatus.open, ReportStatus.resolved), isFalse);
      expect(ReportPolicy.canTransition(ReportStatus.resolved, ReportStatus.open), isFalse);
      expect(ReportPolicy.canTransition(ReportStatus.rejected, ReportStatus.investigating), isFalse);
    });

    test('submission checks', () {
      String? check(String? reason, {String description = '', ReportTarget? target}) => ReportPolicy.checkSubmission(
            reporterId: 'u1',
            target: target ?? _propertyTarget,
            reason: reason,
            description: description,
          );
      expect(check(null), isNotNull);
      expect(check('fraude'), isNull);
      expect(check('autre'), isNotNull); // "Autre" needs details
      expect(check('autre', description: 'Le numéro ne répond jamais'), isNull);
      expect(check('fraude', description: 'x' * 1001), isNotNull);
      expect(check('fraude', target: ReportTarget.property(id: 'p9', title: 'Mon bien', ownerId: 'u1')), isNotNull);
      expect(check('fraude', target: ReportTarget.user(id: 'u1', name: 'moi')), isNotNull);
    });

    test('one report id per reporter and target', () {
      expect(_propertyTarget.reportIdFor('u1'), 'u1_property_p1');
      final msg = ReportTarget.message(messageId: 'm1', conversationId: 'c1', senderId: 's', text: 'x' * 300);
      expect(msg.reportIdFor('u1'), 'u1_message_m1');
      expect(msg.label.length, 200);
      expect(msg.ownerId, 's');
    });

    test('queue order: open work, then priority (escalated), then oldest', () {
      final a = _report(id: 'a', priority: ReportPriority.low, createdAt: DateTime(2026, 1, 1));
      final b = _report(id: 'b', priority: ReportPriority.high, createdAt: DateTime(2026, 3, 1));
      final c = _report(id: 'c', priority: ReportPriority.high, createdAt: DateTime(2026, 2, 1));
      final d = _report(id: 'd', status: ReportStatus.resolved, priority: ReportPriority.high, createdAt: DateTime(2025, 1, 1));
      final e = _report(
        id: 'e',
        priority: ReportPriority.low,
        target: ReportTarget.user(id: 'spammer', name: 'X'),
        createdAt: DateTime(2026, 4, 1),
      );
      final list = [a, b, c, d, e];
      final counts = {'user:spammer': 3};
      list.sort((x, y) => ReportPolicy.compareForQueue(x, y, countByTarget: counts));
      expect(list.map((r) => r.id), ['c', 'b', 'e', 'a', 'd']);
    });

    test('countByTarget', () {
      final counts = ReportPolicy.countByTarget([_report(id: '1'), _report(id: '2')]);
      expect(counts['property:p1'], 2);
    });

    test('tryFromMap', () {
      final r = Report.tryFromMap('u1_property_p1', {
        'reporterId': 'u1',
        'targetType': 'property',
        'targetId': 'p1',
        'targetLabel': 'Villa',
        'targetOwnerId': 'owner',
        'propertyId': 'p1',
        'reason': 'fraude',
        'reasonLabel': 'Fraude',
        'status': 'investigating',
        'priority': 'high',
        'resolutionAction': 'listingSuspended',
        'createdAt': Timestamp.fromDate(DateTime(2026, 11, 18)),
      })!;
      expect(r.target.type, ReportTargetType.property);
      expect(r.status, ReportStatus.investigating);
      expect(r.priority, ReportPriority.high);
      expect(r.resolutionAction, ResolutionAction.listingSuspended);
      expect(r.createdAt, DateTime(2026, 11, 18));
      expect(Report.tryFromMap('x', {'reporterId': 'u1', 'targetType': 'planet', 'targetId': 'a', 'reason': 'r'}), isNull);
    });
  });

  group('ReportActions (users)', () {
    test('submit, duplicates refused, signed-out refused', () async {
      final repo = FakeReportRepository();
      final c = ProviderContainer(overrides: [
        currentUserProvider.overrideWithValue(_me),
        reportRepositoryProvider.overrideWithValue(repo),
      ]);
      addTearDown(c.dispose);
      final actions = c.read(reportActionsProvider);

      expect(await actions.submit(target: _propertyTarget, reasonId: 'fraude', reasonLabel: 'Fraude'), isNull);
      final again = await actions.submit(target: _propertyTarget, reasonId: 'fraude', reasonLabel: 'Fraude');
      expect(again?.type, ReportFailureType.duplicate);
      expect(repo.submitted, ['u1_property_p1']);

      final guest = ProviderContainer(overrides: [
        currentUserProvider.overrideWithValue(null),
        reportRepositoryProvider.overrideWithValue(repo),
      ]);
      addTearDown(guest.dispose);
      final f = await guest.read(reportActionsProvider).submit(target: _propertyTarget, reasonId: 'x', reasonLabel: 'x');
      expect(f?.type, ReportFailureType.permissionDenied);
    });

    test('block / unblock is reflected by isBlockedProvider', () async {
      final repo = FakeReportRepository();
      final c = ProviderContainer(overrides: [
        currentUserProvider.overrideWithValue(_me),
        reportRepositoryProvider.overrideWithValue(repo),
      ]);
      addTearDown(c.dispose);
      c.listen(blockedUsersProvider, (_, _) {});
      await pumpEventQueue();
      expect(c.read(isBlockedProvider('u2')), isFalse);

      await c.read(reportActionsProvider).block('u2', 'Sami');
      await pumpEventQueue();
      expect(c.read(isBlockedProvider('u2')), isTrue);

      await c.read(reportActionsProvider).unblock('u2');
      await pumpEventQueue();
      expect(c.read(isBlockedProvider('u2')), isFalse);
    });
  });

  group('AdminReportActions', () {
    ProviderContainer container(FakeReportRepository reports, FakeAdminRepository admin,
        {PlatformSettings settings = PlatformSettings.defaults}) {
      final c = ProviderContainer(overrides: [
        currentUserProvider.overrideWithValue(_admin),
        reportRepositoryProvider.overrideWithValue(reports),
        adminRepositoryProvider.overrideWithValue(admin),
        platformSettingsProvider.overrideWithValue(settings),
      ]);
      addTearDown(c.dispose);
      return c;
    }

    test('resolving with a measure suspends the listing first, then closes', () async {
      final reports = FakeReportRepository();
      final admin = FakeAdminRepository()..property = makeProperty(id: 'p1', status: PropertyStatus.published);
      final c = container(reports, admin);

      final error = await c.read(adminReportActionsProvider).close(
            _report(),
            to: ReportStatus.resolved,
            note: 'Annonce frauduleuse confirmée',
            action: ResolutionAction.listingSuspended,
          );
      expect(error, isNull);
      expect(admin.calls, ['moderate:p1:suspend']);
      expect(admin.lastModeration!.reason, startsWith('Signalement : '));
      expect(reports.calls, ['close:r1:resolved:listingSuspended:true']);
    });

    test('if the measure is impossible the report stays open', () async {
      final reports = FakeReportRepository();
      final admin = FakeAdminRepository()..property = makeProperty(id: 'p1', status: PropertyStatus.removed);
      final c = container(reports, admin);

      final error = await c.read(adminReportActionsProvider).close(
            _report(),
            to: ReportStatus.resolved,
            note: 'Annonce frauduleuse confirmée',
            action: ResolutionAction.listingSuspended,
          );
      expect(error, isNotNull);
      expect(reports.calls, isEmpty);
    });

    test('banning the reported account', () async {
      final reports = FakeReportRepository();
      final admin = FakeAdminRepository()..user = const AdminUser(id: 'spammer', email: 's@x.tn');
      final c = container(reports, admin, settings: const PlatformSettings(serverNotifications: true));

      final error = await c.read(adminReportActionsProvider).close(
            _report(target: ReportTarget.user(id: 'spammer', name: 'Spam')),
            to: ReportStatus.resolved,
            note: 'Arnaques répétées',
            action: ResolutionAction.userBanned,
          );
      expect(error, isNull);
      expect(admin.calls, ['status:spammer:ban:admin']);
      expect(reports.calls.single, endsWith(':false')); // Functions notify the reporter
    });

    test('rejecting never applies a measure', () async {
      final reports = FakeReportRepository();
      final admin = FakeAdminRepository();
      final c = container(reports, admin);
      await c.read(adminReportActionsProvider).close(
            _report(),
            to: ReportStatus.rejected,
            note: 'Annonce conforme',
            action: ResolutionAction.userBanned,
          );
      expect(admin.calls, isEmpty);
      expect(reports.calls, ['close:r1:rejected:none:true']);
    });
  });

  testWidgets('report sheet: pick a reason and send', (tester) async {
    // A phone-sized screen: the default 800x600 test window is too short for the sheet.
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final repo = FakeReportRepository();
    await tester.pumpWidget(ProviderScope(
      overrides: [
        currentUserProvider.overrideWithValue(_me),
        reportRepositoryProvider.overrideWithValue(repo),
        catalogRepositoryProvider.overrideWithValue(FakeCatalogRepository()),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (ctx) => TextButton(
              onPressed: () => showModalBottomSheet<bool>(
                context: ctx,
                isScrollControlled: true,
                builder: (_) => ReportSheet(target: _propertyTarget),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Envoyer le signalement'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Envoyer le signalement'));
    await tester.pump();
    expect(find.text('Choisissez un motif.'), findsOneWidget);
    expect(repo.submitted, isEmpty);

    await tester.ensureVisible(find.text('Fraude'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Fraude'));
    await tester.pump();
    await tester.ensureVisible(find.text('Envoyer le signalement'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Envoyer le signalement'));
    await tester.pumpAndSettle();
    expect(repo.submitted, ['u1_property_p1']);
    expect(find.byType(ReportSheet), findsNothing); // closed after sending
  });
}
