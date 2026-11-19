import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/property_image.dart';
import '../../../auth/providers/auth_provider.dart';
import '../../../reports/domain/report.dart'; // Module 14
import '../../../reports/presentation/providers/report_providers.dart';
import '../../../reports/presentation/widgets/report_sheet.dart';
import '../../data/conversation_repository.dart';
import '../../domain/conversation.dart';
import '../../domain/message_validator.dart';
import '../../domain/messaging_formatters.dart';
import '../providers/messaging_providers.dart';
import '../widgets/conversation_tile.dart';
import '../widgets/message_bubble.dart';
import '../widgets/message_input.dart';

/// `/chat/:conversationId` (Module 11): the conversation screen. Only the two
/// participants can read or write it (Firestore rules); the thread is tied to
/// ONE property so the professional knows which listing is discussed.
///
/// Older messages load by pages while scrolling up, my latest message shows
/// "Vu" once the other side opened the thread, a message written offline is
/// marked as sending and delivered later. Module 14: report / block.
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
      final outcome =
          await ref.read(conversationRepositoryProvider).sendMessage(widget.conversationId, _controller.text);
      if (!mounted) return;
      _controller.clear();
      if (_scroll.hasClients) _scroll.jumpTo(0);
      if (outcome == SendOutcome.queued) {
        messenger.showSnackBar(const SnackBar(
            content: Text('Pas de connexion. Votre message sera envoyé dès votre retour en ligne.')));
      }
    } on ConversationFailure catch (e) {
      // The text stays in the field so nothing is lost.
      messenger.showSnackBar(SnackBar(
        content: Text(e.message),
        action: e.type == ConversationFailureType.network ? SnackBarAction(label: 'Réessayer', onPressed: _send) : null,
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

    final current = convo.value;
    final party = (current != null && current.participants.contains(me)) ? current : null;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        titleSpacing: 0,
        title: party != null ? _ChatTitle(conversation: party, me: me) : const Text('Conversation'),
        actions: [if (party != null) _SafetyMenu(conversation: party, me: me)],
      ),
      body: convo.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => const _Notice('Cette conversation n\'est pas accessible.'),
        data: (c) {
          if (c == null) return const _Notice('Cette conversation n\'existe pas.');
          if (!c.participants.contains(me)) return const _Notice('Cette conversation n\'est pas accessible.');
          final other = c.otherParticipant(me);
          return Column(children: [
            _PropertyHeader(conversation: c),
            Expanded(child: _buildMessages(c, me, messages, live)),
            if (ref.watch(isBlockedProvider(other)))
              _BlockedBar(onUnblock: () => ref.read(reportActionsProvider).unblock(other))
            else
              MessageInput(controller: _controller, onSend: _send, sending: _sending),
          ]);
        },
      ),
    );
  }

  Widget _buildMessages(Conversation c, String me, AsyncValue<List<ChatMessage>> messages, List<ChatMessage>? live) {
    if (live == null && _lastItems.isEmpty) {
      if (messages.hasError) return const _Notice('Impossible de charger les messages.');
      return const Center(child: CircularProgressIndicator());
    }
    final items = live ?? _lastItems;
    if (items.isEmpty) {
      return const _Notice('Dites bonjour et posez votre question.');
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
      itemBuilder: (context, i) {
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
          MessageBubble(
            key: ValueKey(m.id),
            message: m,
            mine: mine,
            seen: seen,
            // Module 14: long-press a received message to report it.
            onLongPress: mine ? null : () => _reportMessageMenu(context, c, m),
          ),
        ]);
      },
    );
  }

  void _reportMessageMenu(BuildContext context, Conversation c, ChatMessage m) {
    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: ListTile(
          leading: const Icon(Icons.flag_outlined, color: AppColors.error),
          title: const Text('Signaler ce message'),
          onTap: () {
            Navigator.of(ctx).pop();
            showReportSheet(
              context,
              ref,
              ReportTarget.message(
                messageId: m.id,
                conversationId: c.id,
                senderId: m.senderId,
                text: m.text,
                propertyId: c.propertyId,
              ),
            );
          },
        ),
      ),
    );
  }
}

class _ChatTitle extends StatelessWidget {
  const _ChatTitle({required this.conversation, required this.me});

  final Conversation conversation;
  final String me;

  @override
  Widget build(BuildContext context) {
    final name = conversation.partnerNameFor(me);
    final role = me == conversation.userId ? 'Annonceur' : 'Client intéressé';
    return Row(children: [
      ParticipantAvatar(name: name, radius: 18),
      const SizedBox(width: 10),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          Text(name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.text)),
          Text(role, style: const TextStyle(fontSize: 12, color: AppColors.muted)),
        ]),
      ),
    ]);
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

/// Module 14: replaces the input while the other participant is blocked.
class _BlockedBar extends StatelessWidget {
  const _BlockedBar({required this.onUnblock});

  final VoidCallback onUnblock;

  @override
  Widget build(BuildContext context) => SafeArea(
        top: false,
        child: Container(
          width: double.infinity,
          color: AppColors.chip,
          padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
          child: Row(children: [
            const Expanded(
              child: Text('Vous avez bloqué cet utilisateur : vous ne recevez plus ses messages.',
                  style: TextStyle(color: AppColors.navy)),
            ),
            TextButton(onPressed: onUnblock, child: const Text('Débloquer')),
          ]),
        ),
      );
}

/// Module 14 — report or block the other participant.
class _SafetyMenu extends ConsumerWidget {
  const _SafetyMenu({required this.conversation, required this.me});

  final Conversation conversation;
  final String me;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = conversation;
    final otherId = c.otherParticipant(me);
    final otherName = c.partnerNameFor(me);
    final blocked = ref.watch(isBlockedProvider(otherId));

    return PopupMenuButton<String>(
      tooltip: 'Sécurité',
      onSelected: (choice) async {
        final messenger = ScaffoldMessenger.of(context);
        switch (choice) {
          case 'report':
            await showReportSheet(
              context,
              ref,
              ReportTarget.user(id: otherId, name: otherName, conversationId: c.id),
            );
          case 'block':
            final ok = await showDialog<bool>(
              context: context,
              builder: (ctx) => AlertDialog(
                title: const Text('Bloquer cet utilisateur ?'),
                content: const Text(
                  'Il ne pourra plus vous envoyer de messages. Vous pourrez le débloquer '
                  'depuis Profil > Signalements et sécurité.',
                ),
                actions: [
                  TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Annuler')),
                  FilledButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Bloquer')),
                ],
              ),
            );
            if (ok != true) return;
            final f = await ref.read(reportActionsProvider).block(otherId, otherName);
            messenger.showSnackBar(SnackBar(content: Text(f?.message ?? 'Utilisateur bloqué.')));
          case 'unblock':
            final f = await ref.read(reportActionsProvider).unblock(otherId);
            messenger.showSnackBar(SnackBar(content: Text(f?.message ?? 'Utilisateur débloqué.')));
        }
      },
      itemBuilder: (_) => [
        const PopupMenuItem(
          value: 'report',
          child: ListTile(leading: Icon(Icons.flag_outlined), title: Text('Signaler cet utilisateur')),
        ),
        PopupMenuItem(
          value: blocked ? 'unblock' : 'block',
          child: ListTile(
            leading: const Icon(Icons.block),
            title: Text(blocked ? 'Débloquer' : 'Bloquer'),
          ),
        ),
      ],
    );
  }
}

/// The listing this thread is about; opens its details.
class _PropertyHeader extends StatelessWidget {
  const _PropertyHeader({required this.conversation});

  final Conversation conversation;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
        child: Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => context.push(Routes.propertyDetails(conversation.propertyId)),
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Row(children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: SizedBox(
                    width: 48,
                    height: 48,
                    child: PropertyImage(url: conversation.propertyImage, size: PropertyImageSize.thumb),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('À propos de l\'annonce',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.accent)),
                    const SizedBox(height: 2),
                    Text(conversation.propertyTitle ?? 'Annonce',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.text)),
                  ]),
                ),
                const Icon(Icons.chevron_right_rounded, color: AppColors.muted),
              ]),
            ),
          ),
        ),
      );
}
