import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/providers/auth_provider.dart';
import '../../data/conversation_repository.dart';
import '../../domain/conversation.dart';

/// Override in tests with a fake.
final conversationRepositoryProvider = Provider<ConversationRepository>(
  (ref) => ConversationRepository(ref.watch(firestoreProvider), ref.watch(firebaseAuthProvider)),
);

final conversationProvider = StreamProvider.autoDispose.family<Conversation?, String>(
  (ref, id) => ref.watch(conversationRepositoryProvider).watchConversation(id),
);

/// One page worth of messages. Raising [limit] opens a larger window (older
/// messages); the page keeps showing the previous list meanwhile.
typedef MessagesQuery = ({String conversationId, int limit});

final chatMessagesProvider = StreamProvider.autoDispose.family<List<ChatMessage>, MessagesQuery>(
  (ref, q) => ref.watch(conversationRepositoryProvider).watchMessages(q.conversationId, limit: q.limit),
);

/// Inquiries received by the signed-in professional. Resets with the user.
final receivedConversationsProvider = StreamProvider.autoDispose<List<Conversation>>((ref) {
  final uid = ref.watch(currentUserProvider)?.id;
  if (uid == null) return const Stream.empty();
  return ref.watch(conversationRepositoryProvider).watchReceived(uid);
});

/// All conversations of the signed-in user (as buyer/renter or as owner/agent).
/// Resets when the user changes.
final myConversationsProvider = StreamProvider.autoDispose<ConversationList>((ref) {
  final uid = ref.watch(currentUserProvider)?.id;
  if (uid == null) return const Stream.empty();
  return ref.watch(conversationRepositoryProvider).watchMine(uid);
});

/// Number of conversations with an unread message, for the Messages badge.
final unreadConversationsCountProvider = Provider.autoDispose<int>((ref) {
  final uid = ref.watch(currentUserProvider)?.id;
  final list = ref.watch(myConversationsProvider).value;
  if (uid == null || list == null) return 0;
  return list.unreadCountFor(uid);
});
