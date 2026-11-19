import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../domain/conversation.dart';
import '../../domain/messaging_formatters.dart';

/// Initials avatar (profile photos belong to Module 02 and are not in the
/// conversation snapshot).
class ParticipantAvatar extends StatelessWidget {
  const ParticipantAvatar({super.key, required this.name, this.radius = 24});

  final String name;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final trimmed = name.trim();
    final initial = trimmed.isEmpty ? '?' : String.fromCharCode(trimmed.runes.first).toUpperCase();
    return CircleAvatar(
      radius: radius,
      backgroundColor: AppColors.navy,
      child: Text(initial, style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: radius * 0.75)),
    );
  }
}

/// One row of the Messages list: other participant, property, last message,
/// time and unread marker (spec §6.1).
class ConversationTile extends StatelessWidget {
  const ConversationTile({super.key, required this.conversation, required this.me, required this.onTap, this.now});

  final Conversation conversation;
  final String me;
  final VoidCallback onTap;

  /// Injectable for tests.
  final DateTime? now;

  @override
  Widget build(BuildContext context) {
    final c = conversation;
    final unread = c.isUnreadFor(me);
    final who = c.partnerNameFor(me);
    final preview = (c.lastMessage ?? '');
    final shown = c.lastSenderId == me ? 'You: $preview' : preview;

    return Semantics(
      button: true,
      label: '${unread ? 'Unread. ' : ''}$who. ${c.propertyTitle ?? ''}. $preview',
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.line)),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              ParticipantAvatar(name: who),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Expanded(
                      child: Text(who,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontWeight: unread ? FontWeight.w800 : FontWeight.w600, color: AppColors.text)),
                    ),
                    if (c.lastMessageAt != null)
                      Text(formatConversationStamp(c.lastMessageAt!, now: now),
                          style: TextStyle(
                              fontSize: 11,
                              color: unread ? AppColors.primary : AppColors.muted,
                              fontWeight: unread ? FontWeight.w700 : FontWeight.w400)),
                  ]),
                  if (c.propertyTitle != null)
                    Text(c.propertyTitle!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12, color: AppColors.primary, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Text(shown,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 13, color: unread ? AppColors.text : AppColors.muted)),
                ]),
              ),
              if (unread)
                const Padding(
                  padding: EdgeInsets.only(left: 8, top: 4),
                  child: Icon(Icons.circle, size: 10, color: AppColors.primary),
                ),
            ]),
          ),
        ),
      ),
    );
  }
}
