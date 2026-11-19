import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../lib/features/messaging/domain/conversation.dart';
import '../../../lib/features/messaging/presentation/widgets/conversation_tile.dart';
import '../../../lib/features/messaging/presentation/widgets/message_bubble.dart';
import '../../../lib/features/messaging/presentation/widgets/message_input.dart';

Widget wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  testWidgets('send button is disabled for empty text and enabled otherwise', (tester) async {
    final controller = TextEditingController();
    var sent = 0;
    await tester.pumpWidget(wrap(MessageInput(controller: controller, onSend: () => sent++)));

    await tester.tap(find.byTooltip('Send'));
    await tester.pump();
    expect(sent, 0);

    await tester.enterText(find.byType(TextField), '   ');
    await tester.pump();
    await tester.tap(find.byTooltip('Send'));
    expect(sent, 0);

    await tester.enterText(find.byType(TextField), 'Bonjour');
    await tester.pump();
    await tester.tap(find.byTooltip('Send'));
    expect(sent, 1);
  });

  testWidgets('send button is disabled while sending', (tester) async {
    final controller = TextEditingController(text: 'Bonjour');
    var sent = 0;
    await tester.pumpWidget(wrap(MessageInput(controller: controller, onSend: () => sent++, sending: true)));
    await tester.tap(find.byTooltip('Send'));
    expect(sent, 0);
  });

  testWidgets('bubble shows the text and a state label for my messages', (tester) async {
    const m = ChatMessage(id: '1', senderId: 'me', text: 'Salut', pending: true);
    await tester.pumpWidget(wrap(const MessageBubble(message: m, mine: true)));
    expect(find.text('Salut'), findsOneWidget);
    expect(find.bySemanticsLabel('Sending'), findsOneWidget);
  });

  testWidgets('tile shows partner, property, preview and unread marker', (tester) async {
    final c = Conversation(
      id: 'p1_user',
      participants: const ['user', 'owner'],
      userId: 'user',
      recipientId: 'owner',
      propertyId: 'p1',
      recipientName: 'Ahmed Ben Ali',
      propertyTitle: 'Appartement à Sousse',
      lastMessage: 'Le bien est toujours disponible',
      lastMessageAt: DateTime(2026, 11, 13, 10, 42),
      lastSenderId: 'owner',
    );
    await tester.pumpWidget(wrap(ConversationTile(
      conversation: c,
      me: 'user',
      now: DateTime(2026, 11, 13, 12),
      onTap: () {},
    )));
    expect(find.text('Ahmed Ben Ali'), findsOneWidget);
    expect(find.text('Appartement à Sousse'), findsOneWidget);
    expect(find.text('10:42'), findsOneWidget);
    expect(find.byIcon(Icons.circle), findsOneWidget);
  });
}
