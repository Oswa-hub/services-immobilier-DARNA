import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/verification_failure.dart';
import '../../../../core/theme/app_colors.dart';
import '../../domain/entities/verification_record.dart';
import '../providers/verification_providers.dart';

/// One uploaded document. Opening it asks the backend for a short-lived signed
/// link (spec §13.2); the link is never stored, logged or shown as text.
class VerificationDocumentTile extends ConsumerStatefulWidget {
  const VerificationDocumentTile({super.key, required this.verificationId, required this.document});

  final String verificationId;
  final VerificationDocument document;

  @override
  ConsumerState<VerificationDocumentTile> createState() => _VerificationDocumentTileState();
}

class _VerificationDocumentTileState extends ConsumerState<VerificationDocumentTile> {
  bool _loading = false;

  Future<void> _open() async {
    if (_loading) return;
    setState(() => _loading = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final uri = await ref
          .read(verificationRepositoryProvider)
          .documentLink(widget.verificationId, widget.document.documentId);
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (_) => Dialog(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            AppBar(
              title: Text(widget.document.documentType.label),
              automaticallyImplyLeading: false,
              actions: [IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.of(context).pop())],
            ),
            Flexible(
              child: InteractiveViewer(
                child: Image.network(
                  uri.toString(),
                  fit: BoxFit.contain,
                  loadingBuilder: (_, child, p) =>
                      p == null ? child : const Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator()),
                  errorBuilder: (_, __, ___) => const Padding(
                    padding: EdgeInsets.all(24),
                    child: Text('The document could not be displayed.'),
                  ),
                ),
              ),
            ),
          ]),
        ),
      );
    } on VerificationFailure catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      messenger.showSnackBar(
          SnackBar(content: Text(const VerificationFailure(VerificationFailureType.documentAccessFailed).message)));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.document;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.description_outlined, color: AppColors.primary),
      title: Text(d.documentType.label, style: const TextStyle(fontWeight: FontWeight.w700)),
      subtitle: Text('${d.fileName} · ${(d.sizeBytes / 1024).round()} KB'),
      trailing: _loading
          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
          : TextButton(onPressed: _open, child: const Text('View')),
    );
  }
}
