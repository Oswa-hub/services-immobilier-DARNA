import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../domain/conversation.dart';
import '../../domain/messaging_formatters.dart';

/// One chat bubble (DARNA): mine on the right in navy, theirs on the left in
/// white. My messages show their state: sending (clock), sent, seen.
/// [onLongPress] (Module 14) opens the report menu on received messages.
class MessageBubble extends StatelessWidget {
  const MessageBubble({super.key, required this.message, required this.mine, this.seen = false, this.onLongPress});

  final ChatMessage message;
  final bool mine;

  /// The other participant has opened the conversation since this message.
  final bool seen;

  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final fg = mine ? Colors.white : AppColors.text;
    final meta = mine ? Colors.white70 : AppColors.muted;
    final time = message.createdAt;

    final (IconData icon, String label) = message.pending
        ? (Icons.schedule_rounded, 'Envoi en cours')
        : seen
            ? (Icons.done_all_rounded, 'Vu')
            : (Icons.done_rounded, 'Envoyé');

    const r = Radius.circular(18);
    const tail = Radius.circular(4);

    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: GestureDetector(
        onLongPress: onLongPress,
        child: Container(
          constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.78),
          margin: const EdgeInsets.symmetric(vertical: 3),
          padding: const EdgeInsets.fromLTRB(14, 9, 12, 7),
          decoration: BoxDecoration(
            color: mine ? AppColors.navy : Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: r,
              topRight: r,
              bottomLeft: mine ? r : tail,
              bottomRight: mine ? tail : r,
            ),
            boxShadow: mine ? null : const [BoxShadow(color: Color(0x0F0B1F4B), blurRadius: 10, offset: Offset(0, 4))],
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text(message.text, style: TextStyle(color: fg, fontSize: 14.5, height: 1.35)),
            Padding(
              padding: const EdgeInsets.only(top: 3),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                if (time != null) Text(formatClock(time), style: TextStyle(fontSize: 10, color: meta)),
                if (mine) ...[
                  const SizedBox(width: 4),
                  Semantics(
                    container: true,
                    label: label,
                    child: Icon(icon, size: 14, color: seen && !message.pending ? AppColors.accentSoft : meta),
                  ),
                ],
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}

/// Day label between two days of messages ("Aujourd'hui", "Hier", "lun. 09 nov.").
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
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(color: AppColors.chip, borderRadius: BorderRadius.circular(20)),
            child: Text(formatDayLabel(date, now: now),
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.navy)),
          ),
        ),
      );
}
