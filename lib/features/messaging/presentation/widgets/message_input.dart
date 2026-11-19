import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../domain/message_validator.dart';

/// Text field + send button (DARNA). The button is disabled while the text is
/// empty or a send is in progress (no double taps, no duplicated messages).
/// The text is only cleared by the owner of [controller] after a successful send.
class MessageInput extends StatelessWidget {
  const MessageInput({super.key, required this.controller, required this.onSend, this.sending = false});

  final TextEditingController controller;
  final VoidCallback onSend;
  final bool sending;

  @override
  Widget build(BuildContext context) => SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 8, 10, 8),
          decoration: const BoxDecoration(
            color: Colors.white,
            boxShadow: [BoxShadow(color: Color(0x0F0B1F4B), blurRadius: 12, offset: Offset(0, -4))],
          ),
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
                decoration: InputDecoration(
                  hintText: 'Écrire un message…',
                  isDense: true,
                  filled: true,
                  fillColor: AppColors.background,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                  enabledBorder:
                      OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                  focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24), borderSide: const BorderSide(color: AppColors.line)),
                ),
              ),
            ),
            const SizedBox(width: 8),
            ValueListenableBuilder<TextEditingValue>(
              valueListenable: controller,
              builder: (_, value, _) {
                final canSend = !sending && MessageValidator.check(value.text) == null;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: IconButton.filled(
                    tooltip: 'Envoyer',
                    style: IconButton.styleFrom(
                      backgroundColor: AppColors.accent,
                      disabledBackgroundColor: AppColors.line,
                      foregroundColor: Colors.white,
                      fixedSize: const Size(44, 44),
                    ),
                    onPressed: canSend ? onSend : null,
                    icon: sending
                        ? const SizedBox(
                            width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.send_rounded),
                  ),
                );
              },
            ),
          ]),
        ),
      );
}
