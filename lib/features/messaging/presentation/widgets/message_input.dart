import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../domain/message_validator.dart';

/// Text field + send button. The button is disabled while the text is empty or
/// a send is in progress (no double taps, no duplicated messages). The text is
/// only cleared by the owner of [controller] after a successful send.
class MessageInput extends StatelessWidget {
  const MessageInput({super.key, required this.controller, required this.onSend, this.sending = false});

  final TextEditingController controller;
  final VoidCallback onSend;
  final bool sending;

  @override
  Widget build(BuildContext context) => SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
          decoration: const BoxDecoration(color: Colors.white, border: Border(top: BorderSide(color: AppColors.line))),
          child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Expanded(
              child: TextField(
                controller: controller,
                minLines: 1,
                maxLines: 4,
                maxLength: MessageValidator.maxLength,
                textCapitalization: TextCapitalization.sentences,
                keyboardType: TextInputType.multiline,
                buildCounter: (_, {required currentLength, required isFocused, required maxLength}) =>
                    currentLength > (maxLength ?? 0) - 200 ? Text('$currentLength/$maxLength') : null,
                decoration: const InputDecoration(
                  hintText: 'Write a message',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
            ),
            const SizedBox(width: 6),
            ValueListenableBuilder<TextEditingValue>(
              valueListenable: controller,
              builder: (_, value, _) {
                final canSend = !sending && MessageValidator.check(value.text) == null;
                return IconButton.filled(
                  tooltip: 'Send',
                  onPressed: canSend ? onSend : null,
                  icon: sending
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.send_rounded),
                );
              },
            ),
          ]),
        ),
      );
}
