import 'package:flutter/material.dart';

import '../../domain/services/verification_state_machine.dart';

/// Reject dialog: the reason is REQUIRED (spec §6.2 step 7, VER-016).
/// Returns the trimmed reason, or null when cancelled.
Future<String?> askRejectionReason(BuildContext context) => showDialog<String>(
      context: context,
      builder: (_) => const _ReasonDialog(),
    );

class _ReasonDialog extends StatefulWidget {
  const _ReasonDialog();

  @override
  State<_ReasonDialog> createState() => _ReasonDialogState();
}

class _ReasonDialogState extends State<_ReasonDialog> {
  final _controller = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _confirm() {
    final problem = VerificationStateMachine.validateRejectionReason(_controller.text);
    if (problem != null) {
      setState(() => _error = problem);
      return;
    }
    Navigator.of(context).pop(_controller.text.trim());
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: const Text('Request changes'),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('The applicant will read this reason. Do not include document numbers or other sensitive details.'),
          const SizedBox(height: 12),
          TextField(
            controller: _controller,
            maxLines: 4,
            maxLength: 500,
            decoration: InputDecoration(labelText: 'Reason', errorText: _error, border: const OutlineInputBorder()),
          ),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
          FilledButton(onPressed: _confirm, child: const Text('Reject')),
        ],
      );
}

Future<bool> confirmAction(BuildContext context, {required String title, required String message, required String confirmLabel}) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (_) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
        FilledButton(onPressed: () => Navigator.of(context).pop(true), child: Text(confirmLabel)),
      ],
    ),
  );
  return ok ?? false;
}
