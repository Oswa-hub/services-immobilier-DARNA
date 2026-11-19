import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/property_image.dart';
import '../../../auth/providers/auth_provider.dart';
import '../../data/conversation_repository.dart';
import '../../domain/conversation.dart';
import '../../domain/message_validator.dart';
import '../../domain/messaging_formatters.dart';
import '../providers/messaging_providers.dart';
import '../widgets/message_bubble.dart';
import '../widgets/message_input.dart';

/// `/messages/:conversationId`: the conversation screen. Only the two
/// participants can read or write it (Firestore Rules); the thread is tied to
/// ONE property so the professional knows which listing is discussed.
class ChatPage extends ConsumerStatefulWidget {
  const ChatPage({super.key, required this.conversationId});

  final String conversationId;

  @override
  ConsumerState<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends ConsumerState<ChatPage> {
  final _controller = TextEditingController();
  final _scroll = ScrollController();

  bool _sending = false;
  int _limit = ConversationRepository.messagesPageSize;

  /// Last list received, shown while a larger page is loading (no flash).
  List<ChatMessage> _lastItems = const [];

  /// Newest `lastMessageAt` already acknowledged as read (avoids write loops).
  DateTime? _markedUpTo;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    // Opening the conversation, and every later message from the other side
    // while it is open, marks it as read.
    ref.listenManual<AsyncValue<Conversation?>>(
      conversationProvider(widget.conversationId),
      (_, next) => _markReadIfNeeded(next.value),
      fireImmediately: true,
    );
  }

  @override
  void dispose() {
    _scroll.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _markReadIfNeeded(Conversation? c) {
    final me = ref.read(currentUserProvider)?.id;
    if (c == null || me == null || !c.participants.contains(me) || !c.isUnreadFor(me)) return;
    final at = c.lastMessageAt;
    final done = _markedUpTo;
    if (at == null ? done != null : (done != null && !at.isAfter(done))) return;
    _markedUpTo = at ?? DateTime.now();
    ref.read(conversationRepositoryProvider).markRead(c.id);
  }

  /// Older messages: a full page came back, so there may be more.
  bool get _hasMore => _lastItems.length >= _limit;

  void _onScroll() {
    if (!_scroll.hasClients || !_hasMore) return;
    final p = _scroll.position;
    if (p.pixels >= p.maxScrollExtent - 240) {
      setState(() => _limit += ConversationRepository.messagesPageSize);
    }
  }

  Future<void> _send() async {
    if (_sending || MessageValidator.check(_controller.text) != null) return;
    setState(() => _sending = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final outcome = await ref.read(conversationRepositoryProvider).sendMessage(widget.conversationId, _controller.text);
      if (!mounted) return;
      _controller.clear();
      if (_scroll.hasClients) _scroll.jumpTo(0);
      if (outcome == SendOutcome.queued) {
        messenger.showSnackBar(const SnackBar(content: Text('No connection. Your message will be sent when you are back online.')));
      }
    } on ConversationFailure catch (e) {
      // The text stays in the field so nothing is lost.
      messenger.showSnackBar(SnackBar(
        content: Text(e.message),
        action: e.type == ConversationFailureType.network ? SnackBarAction(label: 'Retry', onPressed: _send) : null,
      ));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final me = ref.watch(currentUserProvider)?.id ?? '';
    final convo = ref.watch(conversationProvider(widget.conversationId));
    final messages = ref.watch(chatMessagesProvider((conversationId: widget.conversationId, limit: _limit)));

    final live = messages.value;
    if (live != null) _lastItems = live;

    final c = convo.value;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: Text(c == null ? 'Conversation' : c.partnerNameFor(me))),
      body: convo.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => const _Notice('This conversation is not accessible.'),
        data: (c) {
          if (c == null) return const _Notice('This conversation does not exist.');
          if (!c.participants.contains(me)) return const _Notice('This conversation is not accessible.');
          return Column(children: [
            _PropertyHeader(conversation: c),
            Expanded(child: _buildMessages(c, me, messages, live)),
            MessageInput(controller: _controller, onSend: _send, sending: _sending),
          ]);
        },
      ),
    );
  }

  Widget _buildMessages(Conversation c, String me, AsyncValue<List<ChatMessage>> messages, List<ChatMessage>? live) {
    if (live == null && _lastItems.isEmpty) {
      if (messages.hasError) return const _Notice('We could not load the messages.');
      return const Center(child: CircularProgressIndicator());
    }
    final items = live ?? _lastItems;
    if (items.isEmpty) {
      return const Center(child: Text('Say hello and ask your question.', style: TextStyle(color: AppColors.muted)));
    }

    final other = c.otherParticipant(me);
    // Items are newest first: the first one sent by me is my latest message.
    final lastMine = items.indexWhere((m) => m.senderId == me);
    final hasMore = _hasMore;

    DateTime at(ChatMessage m) => (m.createdAt ?? DateTime.now()).toLocal();

    return ListView.builder(
      controller: _scroll,
      reverse: true,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      itemCount: items.length + (hasMore ? 1 : 0),
      itemBuilder: (_, i) {
        if (i == items.length) {
          return const Padding(
            padding: EdgeInsets.all(12),
            child: Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))),
          );
        }
        final m = items[i];
        final mine = m.senderId == me;
        // Oldest loaded message: label its day only when no older history remains.
        final first = i == items.length - 1 ? !hasMore : !isSameDay(at(m), at(items[i + 1]));
        final created = m.createdAt;
        final seen = mine && i == lastMine && created != null && c.wasReadBy(other, created);
        return Column(children: [
          if (first) DateSeparator(date: at(m)),
          MessageBubble(message: m, mine: mine, seen: seen),
        ]);
      },
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Text(text, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.muted)),
        ),
      );
}

class _PropertyHeader extends StatelessWidget {
  const _PropertyHeader({required this.conversation});

  final Conversation conversation;

  @override
  Widget build(BuildContext context) => Material(
        color: Colors.white,
        child: InkWell(
          onTap: () => context.push(Routes.propertyDetails(conversation.propertyId)),
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Row(children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: SizedBox(width: 48, height: 48, child: PropertyImage(url: conversation.propertyImage, size: PropertyImageSize.thumb)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(conversation.propertyTitle ?? 'Property',
                    maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700)),
              ),
              const Icon(Icons.chevron_right_rounded, color: AppColors.muted),
            ]),
          ),
        ),
      );
}
