import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/property_image.dart';
import '../../domain/conversation.dart';
import '../../domain/messaging_formatters.dart';

const _cardShadow = [BoxShadow(color: Color(0x140B1F4B), blurRadius: 18, offset: Offset(0, 8))];

/// Initials avatar (profile photos are not in the conversation snapshot).
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

/// One row of the Messages list (DARNA card): other participant with the
/// listing thumbnail, the listing title, last message, time and unread marker.
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
    final preview = c.lastMessage ?? '';
    final shown = c.lastSenderId == me ? 'Vous : $preview' : preview;

    return Semantics(
      button: true,
      label: '${unread ? 'Non lu. ' : ''}$who. ${c.propertyTitle ?? ''}. $preview',
      excludeSemantics: true,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: _cardShadow,
          border: unread ? Border.all(color: AppColors.accent.withValues(alpha: 0.45)) : null,
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                SizedBox(
                  width: 52,
                  height: 52,
                  child: Stack(clipBehavior: Clip.none, children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: SizedBox(
                        width: 52,
                        height: 52,
                        child: PropertyImage(url: c.propertyImage, size: PropertyImageSize.thumb),
                      ),
                    ),
                    Positioned(
                      right: -6,
                      bottom: -6,
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                        child: ParticipantAvatar(name: who, radius: 12),
                      ),
                    ),
                  ]),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Expanded(
                        child: Text(who,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                fontSize: 15,
                                fontWeight: unread ? FontWeight.w800 : FontWeight.w700,
                                color: AppColors.text)),
                      ),
                      if (c.lastMessageAt != null)
                        Text(formatConversationStamp(c.lastMessageAt!, now: now),
                            style: TextStyle(
                                fontSize: 11,
                                color: unread ? AppColors.accent : AppColors.muted,
                                fontWeight: unread ? FontWeight.w800 : FontWeight.w500)),
                    ]),
                    if (c.propertyTitle != null) ...[
                      const SizedBox(height: 2),
                      Text(c.propertyTitle!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 12, color: AppColors.accent, fontWeight: FontWeight.w700)),
                    ],
                    const SizedBox(height: 4),
                    Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Expanded(
                        child: Text(shown,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                fontSize: 13,
                                height: 1.3,
                                color: unread ? AppColors.text : AppColors.muted,
                                fontWeight: unread ? FontWeight.w600 : FontWeight.w400)),
                      ),
                      if (unread)
                        Container(
                          margin: const EdgeInsets.only(left: 8, top: 4),
                          width: 10,
                          height: 10,
                          decoration: const BoxDecoration(color: AppColors.accent, shape: BoxShape.circle),
                        ),
                    ]),
                  ]),
                ),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}
