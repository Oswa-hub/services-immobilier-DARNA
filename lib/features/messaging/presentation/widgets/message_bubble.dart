import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../domain/conversation.dart';
import '../../domain/messaging_formatters.dart';

/// One chat bubble. Mine on the right (brand color), theirs on the left.
/// For my messages the footer shows the state: waiting (clock), sent, seen.
class MessageBubble extends StatelessWidget {
  const MessageBubble({super.key, required this.message, required this.mine, this.seen = false});

  final ChatMessage message;
  final bool mine;

  /// The other participant has opened the conversation since this message.
  final bool seen;

  @override
  Widget build(BuildContext context) {
    final fg = mine ? Colors.white : AppColors.text;
    final meta = mine ? Colors.white70 : AppColors.muted;
    final time = message.createdAt;

    final (IconData icon, String label) = message.pending
        ? (Icons.schedule_rounded, 'Sending')
        : seen
            ? (Icons.done_all_rounded, 'Seen')
            : (Icons.done_rounded, 'Sent');

    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.78),
        margin: const EdgeInsets.symmetric(vertical: 3),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: mine ? AppColors.primary : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: mine ? null : Border.all(color: AppColors.line),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          SelectableText(message.text, style: TextStyle(color: fg, height: 1.35)),
          Padding(
            padding: const EdgeInsets.only(top: 3),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              if (time != null) Text(formatClock(time), style: TextStyle(fontSize: 10, color: meta)),
              if (mine) ...[
                const SizedBox(width: 4),
                Semantics(label: label, child: Icon(icon, size: 13, color: meta)),
              ],
            ]),
          ),
        ]),
      ),
    );
  }
}

/// Day label between two days of messages ("Today", "Yesterday", "Mon 09 Nov").
class DateSeparator extends StatelessWidget {
  const DateSeparator({super.key, required this.date, this.now});

  final DateTime date;

  /// Injectable for tests.
  final DateTime? now;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(color: AppColors.line.withValues(alpha: 0.6), borderRadius: BorderRadius.circular(10)),
            child: Text(formatDayLabel(date, now: now),
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.muted)),
          ),
        ),
      );
}
