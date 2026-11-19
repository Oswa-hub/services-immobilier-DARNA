import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:team_app/core/theme/app_theme.dart';
import 'package:team_app/features/auth/domain/entities/auth_user.dart';
import 'package:team_app/features/auth/providers/auth_provider.dart';
import 'package:team_app/features/messaging/domain/conversation.dart';
import 'package:team_app/features/messaging/presentation/pages/conversations_page.dart';
import 'package:team_app/features/messaging/presentation/providers/messaging_providers.dart';
import 'package:team_app/features/messaging/presentation/widgets/conversation_tile.dart';
import 'package:team_app/features/messaging/presentation/widgets/message_bubble.dart';
import 'package:team_app/features/messaging/presentation/widgets/message_input.dart';

const me = AuthUser(id: 'u', email: 'u@x.tn', name: 'Yahya', emailVerified: true);
final t = DateTime(2026, 11, 19, 10, 42);

Conversation convo({String id = 'p_u', String? sender = 'a', Map<String, DateTime> read = const {}}) => Conversation(
      id: id,
      participants: const ['u', 'a'],
      userId: 'u',
      recipientId: 'a',
      propertyId: 'p',
      recipientName: 'Agence Lac',
      propertyTitle: 'Villa La Marsa',
      lastMessage: 'Le bien est toujours disponible.',
      lastMessageAt: t,
      lastSenderId: sender,
      lastReadAt: read,
    );

Widget app(Widget child) => MaterialApp(theme: AppTheme.light, home: Scaffold(body: child));

void main() {
  group('ConversationTile', () {
    testWidgets('shows partner, listing, preview and the unread dot', (tester) async {
      await tester.pumpWidget(app(ConversationTile(conversation: convo(), me: 'u', onTap: () {}, now: t)));
      expect(find.text('Agence Lac'), findsOneWidget);
      expect(find.text('Villa La Marsa'), findsOneWidget);
      expect(find.text('Le bien est toujours disponible.'), findsOneWidget);
      expect(find.text('10:42'), findsOneWidget);
      expect(find.bySemanticsLabel(RegExp('^Non lu')), findsOneWidget);
    });

    testWidgets('my own last message is prefixed and not unread', (tester) async {
      await tester.pumpWidget(app(ConversationTile(conversation: convo(sender: 'u'), me: 'u', onTap: () {}, now: t)));
      expect(find.text('Vous : Le bien est toujours disponible.'), findsOneWidget);
      expect(find.bySemanticsLabel(RegExp('^Non lu')), findsNothing);
    });
  });

  group('MessageBubble', () {
    ChatMessage msg({bool pending = false}) =>
        ChatMessage(id: 'm', senderId: 'u', text: 'Bonjour', createdAt: t, pending: pending);

    testWidgets('my message: sending, sent, seen', (tester) async {
      await tester.pumpWidget(app(MessageBubble(message: msg(pending: true), mine: true)));
      expect(find.bySemanticsLabel('Envoi en cours'), findsOneWidget);

      await tester.pumpWidget(app(MessageBubble(message: msg(), mine: true)));
      expect(find.bySemanticsLabel('Envoyé'), findsOneWidget);

      await tester.pumpWidget(app(MessageBubble(message: msg(), mine: true, seen: true)));
      expect(find.bySemanticsLabel('Vu'), findsOneWidget);
    });

    testWidgets('received message has no state and reports on long-press', (tester) async {
      var reported = false;
      await tester.pumpWidget(app(MessageBubble(message: msg(), mine: false, onLongPress: () => reported = true)));
      expect(find.bySemanticsLabel('Envoyé'), findsNothing);
      await tester.longPress(find.text('Bonjour'));
      expect(reported, isTrue);
    });
  });

  testWidgets('MessageInput: send is disabled until there is text', (tester) async {
    final controller = TextEditingController();
    var sent = 0;
    await tester.pumpWidget(app(MessageInput(controller: controller, onSend: () => sent++)));

    await tester.tap(find.byTooltip('Envoyer'));
    expect(sent, 0);

    await tester.enterText(find.byType(TextField), '  Bonjour ');
    await tester.pump();
    await tester.tap(find.byTooltip('Envoyer'));
    expect(sent, 1);
  });

  group('ConversationsPage', () {
    Future<void> pump(WidgetTester tester, Stream<ConversationList> stream) async {
      await tester.pumpWidget(ProviderScope(
        // Riverpod 3 retries failed providers on a timer: off, so the error
        // state stays put and no timer is left pending at the end of the test.
        retry: (_, _) => null,
        overrides: [
          currentUserProvider.overrideWithValue(me),
          myConversationsProvider.overrideWith((ref) => stream),
        ],
        child: MaterialApp(theme: AppTheme.light, home: const ConversationsPage()),
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
    }

    testWidgets('lists conversations and counts the unread ones', (tester) async {
      await pump(
        tester,
        Stream.value(ConversationList(items: [convo(), convo(id: 'p2_u', sender: 'u')])),
      );
      expect(find.byType(ConversationTile), findsNWidgets(2));
      expect(find.text('1 conversation non lue'), findsOneWidget);
    });

    testWidgets('empty state invites to browse listings', (tester) async {
      await pump(tester, Stream.value(const ConversationList(items: [])));
      expect(find.text('Aucune conversation'), findsOneWidget);
      expect(find.text('Explorer les biens'), findsOneWidget);
    });

    testWidgets('error state offers a retry', (tester) async {
      await pump(tester, Stream.error(Exception('offline')));
      expect(find.text('Impossible de charger vos conversations.'), findsOneWidget);
    });
  });
}
