import 'package:flutter_test/flutter_test.dart';

import '../../../lib/features/messaging/domain/conversation.dart';

Conversation convo({
  String? lastMessage = 'Hi',
  String? lastSenderId = 'owner',
  DateTime? lastMessageAt,
  Map<String, DateTime> lastReadAt = const {},
  String? userName = 'Sami',
  String? recipientName,
}) =>
    Conversation(
      id: 'p1_user',
      participants: const ['user', 'owner'],
      userId: 'user',
      recipientId: 'owner',
      propertyId: 'p1',
      userName: userName,
      recipientName: recipientName,
      lastMessage: lastMessage,
      lastMessageAt: lastMessageAt ?? DateTime(2026, 11, 12, 10, 0),
      lastSenderId: lastSenderId,
      lastReadAt: lastReadAt,
    );

void main() {
  group('isUnreadFor', () {
    test('a thread without messages is never unread', () {
      expect(convo(lastMessage: null, lastSenderId: null).isUnreadFor('user'), isFalse);
    });

    test('my own last message is not unread for me', () {
      expect(convo(lastSenderId: 'user').isUnreadFor('user'), isFalse);
    });

    test('unread when the other side wrote and I never opened it', () {
      expect(convo().isUnreadFor('user'), isTrue);
    });

    test('read once I opened it after the last message', () {
      final c = convo(lastReadAt: {'user': DateTime(2026, 11, 12, 10, 5)});
      expect(c.isUnreadFor('user'), isFalse);
    });

    test('unread again when a newer message arrives', () {
      final c = convo(
        lastMessageAt: DateTime(2026, 11, 12, 11, 0),
        lastReadAt: {'user': DateTime(2026, 11, 12, 10, 5)},
      );
      expect(c.isUnreadFor('user'), isTrue);
    });
  });

  group('partner and seen', () {
    test('partnerNameFor shows the other side', () {
      final c = convo(recipientName: 'Agence Immo Tunis');
      expect(c.partnerNameFor('user'), 'Agence Immo Tunis');
      expect(c.partnerNameFor('owner'), 'Sami');
    });

    test('falls back when snapshots are missing', () {
      final c = convo(userName: null);
      expect(c.partnerNameFor('user'), 'Advertiser');
      expect(c.partnerNameFor('owner'), 'Interested user');
    });

    test('wasReadBy compares the read time with the message time', () {
      final at = DateTime(2026, 11, 12, 10, 0);
      final c = convo(lastReadAt: {'owner': DateTime(2026, 11, 12, 10, 1)});
      expect(c.wasReadBy('owner', at), isTrue);
      expect(c.wasReadBy('owner', DateTime(2026, 11, 12, 10, 2)), isFalse);
      expect(c.wasReadBy('user', at), isFalse);
    });
  });

  group('ConversationList', () {
    test('counts unread conversations for a user', () {
      final list = ConversationList(items: [convo(), convo(lastSenderId: 'user'), convo()]);
      expect(list.unreadCountFor('user'), 2);
      expect(list.unreadCountFor('owner'), 1);
    });
  });
}
