import 'package:flutter_test/flutter_test.dart';
import 'package:team_app/features/messaging/domain/conversation.dart';
import 'package:team_app/features/messaging/domain/message_validator.dart';
import 'package:team_app/features/messaging/domain/messaging_formatters.dart';

Conversation convo({
  String id = 'p_u',
  String? sender,
  DateTime? at,
  Map<String, DateTime> read = const {},
  String? userName,
  String? recipientName,
  String? last = 'Bonjour',
}) =>
    Conversation(
      id: id,
      participants: const ['u', 'a'],
      userId: 'u',
      recipientId: 'a',
      propertyId: 'p',
      userName: userName,
      recipientName: recipientName,
      lastMessage: last,
      lastMessageAt: at,
      lastSenderId: sender,
      lastReadAt: read,
    );

void main() {
  group('MessageValidator', () {
    test('empty and blank text cannot be sent', () {
      expect(MessageValidator.check(null), MessageIssue.empty);
      expect(MessageValidator.check('   \n '), MessageIssue.empty);
      expect(MessageValidator.check(' Bonjour '), isNull);
    });

    test('length is counted in characters, emoji included', () {
      expect(MessageValidator.check('a' * MessageValidator.maxLength), isNull);
      expect(MessageValidator.check('a' * (MessageValidator.maxLength + 1)), MessageIssue.tooLong);
      expect(MessageValidator.check('🏠' * MessageValidator.maxLength), isNull);
    });

    test('preview is cut without splitting an emoji', () {
      final long = '🏠' * (MessageValidator.previewLength + 5);
      final p = MessageValidator.preview(long);
      expect(p.runes.length, MessageValidator.previewLength + 1); // + ellipsis
      expect(p.endsWith('…'), isTrue);
      expect(MessageValidator.preview('court'), 'court');
    });
  });

  group('formatters (French)', () {
    final now = DateTime(2026, 11, 19, 15, 30);

    test('conversation stamp', () {
      expect(formatConversationStamp(DateTime(2026, 11, 19, 9, 5), now: now), '09:05');
      expect(formatConversationStamp(DateTime(2026, 11, 18, 22), now: now), 'Hier');
      expect(formatConversationStamp(DateTime(2026, 11, 16, 10), now: now), 'lun.');
      expect(formatConversationStamp(DateTime(2026, 11, 2, 10), now: now), '02 nov.');
      expect(formatConversationStamp(DateTime(2025, 12, 24, 10), now: now), '24 déc. 2025');
    });

    test('day label', () {
      expect(formatDayLabel(DateTime(2026, 11, 19, 1), now: now), "Aujourd'hui");
      expect(formatDayLabel(DateTime(2026, 11, 18, 1), now: now), 'Hier');
      expect(formatDayLabel(DateTime(2026, 11, 9, 1), now: now), 'lun. 09 nov.');
    });

    test('isSameDay', () {
      expect(isSameDay(DateTime(2026, 11, 19, 0, 1), DateTime(2026, 11, 19, 23, 59)), isTrue);
      expect(isSameDay(DateTime(2026, 11, 19), DateTime(2026, 11, 20)), isFalse);
    });
  });

  group('Conversation', () {
    final t = DateTime(2026, 11, 19, 12);

    test('partner name seen from each side, with fallbacks', () {
      final c = convo(userName: 'Sami', recipientName: 'Agence Lac');
      expect(c.partnerNameFor('u'), 'Agence Lac');
      expect(c.partnerNameFor('a'), 'Sami');
      expect(convo().partnerNameFor('u'), 'Annonceur');
      expect(convo().partnerNameFor('a'), 'Utilisateur intéressé');
    });

    test('wasReadBy: seen once the other side opened the thread after the message', () {
      final c = convo(read: {'a': t});
      expect(c.wasReadBy('a', t.subtract(const Duration(minutes: 1))), isTrue);
      expect(c.wasReadBy('a', t), isTrue);
      expect(c.wasReadBy('a', t.add(const Duration(seconds: 1))), isFalse);
      expect(c.wasReadBy('u', t), isFalse);
    });

    test('unread count only counts threads with a newer message from the other side', () {
      final list = ConversationList(items: [
        convo(id: '1', sender: 'a', at: t), // unread for u
        convo(id: '2', sender: 'u', at: t), // my own message
        convo(id: '3', sender: 'a', at: t, read: {'u': t.add(const Duration(minutes: 1))}), // read
      ]);
      expect(list.unreadCountFor('u'), 1);
      expect(list.unreadCountFor('a'), 1);
    });

    test('a thread without messages is not shown and never unread', () {
      final empty = convo(last: null, sender: 'a', at: t);
      expect(empty.hasMessages, isFalse);
      expect(empty.isUnreadFor('u'), isFalse);
    });
  });
}
