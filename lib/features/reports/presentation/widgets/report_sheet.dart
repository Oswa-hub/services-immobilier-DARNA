import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../auth/providers/auth_provider.dart';
import '../../../content/domain/catalog.dart';
import '../../../content/presentation/providers/catalog_providers.dart';
import '../../domain/report.dart';
import '../providers/report_providers.dart';

/// Opens the report form for [target]. Guests are sent to the login page.
/// Returns true when a report was sent.
Future<bool> showReportSheet(BuildContext context, WidgetRef ref, ReportTarget target) async {
  if (ref.read(currentUserProvider) == null) {
    context.push(Routes.login);
    return false;
  }
  final sent = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => ReportSheet(target: target),
  );
  return sent ?? false;
}

/// Module 14 — "Signaler" form: reason (admin-managed list, Module 16) +
/// optional details.
class ReportSheet extends ConsumerStatefulWidget {
  const ReportSheet({super.key, required this.target});

  final ReportTarget target;

  @override
  ConsumerState<ReportSheet> createState() => _ReportSheetState();
}

class _ReportSheetState extends ConsumerState<ReportSheet> {
  CatalogItem? _reason;
  final _details = TextEditingController();
  String? _error;
  bool _sending = false;

  @override
  void dispose() {
    _details.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final reason = _reason;
    final problem = ReportPolicy.checkSubmission(
      reporterId: ref.read(currentUserProvider)?.id ?? '',
      target: widget.target,
      reason: reason?.id,
      description: _details.text,
    );
    if (problem != null) {
      setState(() => _error = problem);
      return;
    }
    setState(() {
      _sending = true;
      _error = null;
    });
    final failure = await ref.read(reportActionsProvider).submit(
          target: widget.target,
          reasonId: reason!.id,
          reasonLabel: reason.label,
          description: _details.text,
        );
    if (!mounted) return;
    if (failure != null) {
      setState(() {
        _sending = false;
        _error = failure.message;
      });
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text('Merci, votre signalement a été envoyé. Vous pouvez le suivre dans Profil > Mes signalements.'),
    ));
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final reasons = ref.watch(activeCatalogProvider(CatalogKey.reportReasons));
    final t = widget.target;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Signaler : ${t.type.label.toLowerCase()}',
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.navy)),
            if (t.label.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(t.label, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppColors.muted)),
            ],
            const SizedBox(height: 12),
            const Text('Quel est le problème ?', style: TextStyle(fontWeight: FontWeight.w700)),
            RadioGroup<String>(
              groupValue: _reason?.id,
              onChanged: (id) => setState(() => _reason = reasons.where((r) => r.id == id).firstOrNull),
              child: Column(children: [
                for (final r in reasons)
                  RadioListTile<String>(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    value: r.id,
                    title: Text(r.label),
                  ),
              ]),
            ),
            TextField(
              controller: _details,
              minLines: 2,
              maxLines: 5,
              maxLength: ReportPolicy.maxDescription,
              decoration: InputDecoration(
                labelText: _reason?.id == 'autre' ? 'Détails (obligatoire)' : 'Détails (facultatif)',
                border: const OutlineInputBorder(),
              ),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(_error!, style: const TextStyle(color: AppColors.error)),
              ),
            const Text(
              'Les signalements sont confidentiels : la personne signalée ne sait pas qui l’a signalée.',
              style: TextStyle(fontSize: 12.5, color: AppColors.muted),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _sending ? null : _submit,
                icon: _sending
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.flag_outlined),
                label: const Text('Envoyer le signalement'),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

/// Flag icon for app bars.
class ReportButton extends ConsumerWidget {
  const ReportButton({super.key, required this.target, this.tooltip = 'Signaler'});

  final ReportTarget target;
  final String tooltip;

  @override
  Widget build(BuildContext context, WidgetRef ref) => IconButton(
        tooltip: tooltip,
        icon: const Icon(Icons.flag_outlined),
        onPressed: () => showReportSheet(context, ref, target),
      );
}
