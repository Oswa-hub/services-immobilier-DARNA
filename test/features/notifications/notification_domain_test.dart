// Module 12 pure logic: mapper, preferences, navigation, grouping.
// Run: flutter test test/features/notifications
import 'package:cloud_firestore/cloud_firestore.dart' show Timestamp;
import 'package:flutter_test/flutter_test.dart';

import 'package:team_app/app/routes.dart';
import 'package:team_app/features/notifications/data/notification_mapper.dart';
import 'package:team_app/features/notifications/domain/entities/app_notification.dart';
import 'package:team_app/features/notifications/domain/entities/notification_preferences.dart';
import 'package:team_app/features/notifications/domain/services/notification_grouping.dart';
import 'package:team_app/features/notifications/domain/services/notification_navigation.dart';

import 'fakes.dart';

void main() {
  group('NotificationType', () {
    test('parses known names and falls back to other', () {
      expect(NotificationType.parse('priceChanged'), NotificationType.priceChanged);
      expect(NotificationType.parse('somethingNew'), NotificationType.other);
      expect(NotificationType.parse(null), NotificationType.other);
    });

    test('categories match the server (functions/src/notification_rules.js)', () {
      expect(NotificationType.newInquiry.category, NotificationCategory.messages);
      expect(NotificationType.priceChanged.category, NotificationCategory.favorites);
      expect(NotificationType.newMatchingProperty.category, NotificationCategory.alerts);
      expect(NotificationType.platformAnnouncement.category, NotificationCategory.announcements);
      expect(NotificationType.listingRejected.category, NotificationCategory.account);
      expect(NotificationType.accountWarning.category, NotificationCategory.account);
    });
  });

  group('NotificationMapper', () {
    test('maps a full document', () {
      final created = DateTime(2026, 11, 17, 10, 30);
      final n = NotificationMapper.tryFromMap('n1', {
        'userId': 'u1',
        'type': 'priceChanged',
        'title': 'Baisse de prix',
        'body': '500 000 TND → 450 000 TND',
        'read': false,
        'propertyId': 'p1',
        'createdAt': Timestamp.fromDate(created),
        'data': {'oldPrice': 500000, 'newPrice': 450000},
      })!;
      expect(n.id, 'n1');
      expect(n.type, NotificationType.priceChanged);
      expect(n.read, isFalse);
      expect(n.propertyId, 'p1');
      expect(n.conversationId, isNull);
      expect(n.createdAt, created);
      expect(n.data['newPrice'], 450000);
    });

    test('tolerates missing optional fields and a pending timestamp', () {
      final n = NotificationMapper.tryFromMap('n2', {'userId': 'u1', 'title': 'Hello', 'createdAt': null})!;
      expect(n.body, '');
      expect(n.read, isFalse);
      expect(n.type, NotificationType.other);
      expect(n.createdAt, isNull);
      expect(n.data, isEmpty);
    });

    test('skips malformed documents', () {
      expect(NotificationMapper.tryFromMap('n3', {'userId': 'u1'}), isNull); // no title
      expect(NotificationMapper.tryFromMap('n4', {'title': 'x'}), isNull); // no user
      expect(NotificationMapper.tryFromMap('n5', {'userId': 'u1', 'title': '   '}), isNull);
    });
  });

  group('NotificationPreferences', () {
    test('defaults: everything on except email', () {
      final p = NotificationPreferences.fromMap(null);
      expect(p, NotificationPreferences.defaults);
      expect(p.pushNotifications, isTrue);
      expect(p.emailNotifications, isFalse);
    });

    test('keeps the legacy keys and ignores bad values', () {
      final p = NotificationPreferences.fromMap({
        'newMessages': false,
        'favoriteUpdates': true,
        'propertyAlerts': 'no',
        'emailNotifications': true,
      });
      expect(p.newMessages, isFalse);
      expect(p.propertyAlerts, isTrue); // non-bool -> default
      expect(p.emailNotifications, isTrue);
      expect(NotificationPreferences.fromMap(p.toMap()), p); // round trip
    });

    test('account notifications cannot be switched off', () {
      const off = NotificationPreferences(
        newMessages: false,
        favoriteUpdates: false,
        propertyAlerts: false,
        announcements: false,
      );
      expect(off.allows(NotificationCategory.account), isTrue);
      expect(off.allows(NotificationCategory.messages), isFalse);
      expect(off.allows(NotificationCategory.alerts), isFalse);
    });
  });

  group('routeForNotification', () {
    String? route(NotificationType t, {String? propertyId, String? conversationId}) =>
        routeForNotification(type: t, propertyId: propertyId, conversationId: conversationId);

    test('a conversation always wins', () {
      expect(route(NotificationType.newMessage, conversationId: 'p1_u2', propertyId: 'p1'), Routes.chat('p1_u2'));
    });

    test('visible listings open their details', () {
      expect(route(NotificationType.listingApproved, propertyId: 'p1'), Routes.propertyDetails('p1'));
      expect(route(NotificationType.priceChanged, propertyId: 'p1'), Routes.propertyDetails('p1'));
      expect(route(NotificationType.newMatchingProperty, propertyId: 'p9'), Routes.propertyDetails('p9'));
    });

    test('listings that are not public go to My Listings', () {
      expect(route(NotificationType.listingRejected, propertyId: 'p1'), Routes.myListings);
      expect(route(NotificationType.listingSuspended, propertyId: 'p1'), Routes.myListings);
      expect(route(NotificationType.listingApproved), Routes.myListings); // no id
    });

    test('verification and self-contained notifications', () {
      expect(route(NotificationType.verificationApproved), Routes.agentVerification);
      expect(route(NotificationType.platformAnnouncement), isNull);
      expect(route(NotificationType.accountWarning), isNull);
      expect(route(NotificationType.other), isNull);
    });
  });

  group('grouping and time labels', () {
    final now = DateTime(2026, 11, 17, 20, 0);

    test('sections', () {
      expect(sectionFor(DateTime(2026, 11, 17, 1), now), NotificationSection.today);
      expect(sectionFor(null, now), NotificationSection.today);
      expect(sectionFor(DateTime(2026, 11, 16, 23, 59), now), NotificationSection.yesterday);
      expect(sectionFor(DateTime(2026, 11, 12), now), NotificationSection.thisWeek);
      expect(sectionFor(DateTime(2026, 11, 1), now), NotificationSection.older);
    });

    test('groupNotifications keeps order and drops empty sections', () {
      final groups = groupNotifications([
        makeNotification(id: 'a', createdAt: DateTime(2026, 11, 17, 19)),
        makeNotification(id: 'b', createdAt: DateTime(2026, 11, 17, 8)),
        makeNotification(id: 'c', createdAt: DateTime(2026, 10, 1)),
      ], now: now);
      expect(groups.map((g) => g.section), [NotificationSection.today, NotificationSection.older]);
      expect(groups.first.items.map((n) => n.id), ['a', 'b']);
    });

    test('formatNotificationTime', () {
      expect(formatNotificationTime(null, now: now), 'À l’instant');
      expect(formatNotificationTime(now.subtract(const Duration(seconds: 20)), now: now), 'À l’instant');
      expect(formatNotificationTime(now.subtract(const Duration(minutes: 5)), now: now), 'il y a 5 min');
      expect(formatNotificationTime(now.subtract(const Duration(hours: 3)), now: now), 'il y a 3 h');
      expect(formatNotificationTime(DateTime(2026, 11, 16, 22), now: now), 'Hier');
      expect(formatNotificationTime(DateTime(2026, 3, 2, 9), now: now), '02/03/2026');
    });

    test('unreadBadgeLabel', () {
      expect(unreadBadgeLabel(0), isNull);
      expect(unreadBadgeLabel(7), '7');
      expect(unreadBadgeLabel(100), '99+');
    });
  });
}
