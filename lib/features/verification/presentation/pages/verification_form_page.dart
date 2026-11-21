import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/errors/verification_failure.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../agents/presentation/providers/agent_providers.dart';
import '../../../agents/presentation/widgets/agent_states.dart';
import '../../../auth/providers/auth_provider.dart';
import '../../../listings/providers/my_listings_providers.dart';
import '../../../properties/domain/entities/property.dart';
import '../../domain/entities/verification_enums.dart';
import '../../domain/entities/verification_submission.dart';
import '../../domain/services/verification_policy.dart';
import '../../domain/services/verification_state_machine.dart';
import '../providers/verification_providers.dart';
import '../widgets/document_upload_field.dart';
import '../widgets/verification_status_badge.dart';

/// Submit or correct a verification request (spec §6.1, §6.3).
/// Handles every UI state of §12.2: loading, empty, submitting, validation,
/// server and permission errors, success.
class VerificationFormPage extends ConsumerStatefulWidget {
  const VerificationFormPage({super.key, required this.targetType, required this.targetId});

  final VerificationTargetType targetType;
  final String targetId;

  @override
  ConsumerState<VerificationFormPage> createState() => _VerificationFormPageState();
}

class _VerificationFormPageState extends ConsumerState<VerificationFormPage> {
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _propertyRef = TextEditingController();
  final _agencyName = TextEditingController();
  final _agencyAddress = TextEditingController();
  final _picker = ImagePicker();
  final Map<VerificationDocumentType, List<VerificationFile>> _files = {};
  final Map<String, String> _localErrors = {};
  bool _prefilled = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => ref.read(verificationFormProvider.notifier).reset());
  }

  @override
  void dispose() {
    for (final c in [_name, _phone, _propertyRef, _agencyName, _agencyAddress]) {
      c.dispose();
    }
    super.dispose();
  }

  void _prefill() {
    if (_prefilled) return;
    _prefilled = true;
    final u = ref.read(currentUserProvider);
    _name.text = u?.name ?? '';
    _phone.text = u?.phone ?? '';
  }

  Future<void> _add(VerificationDocumentType type, ImageSource source) async {
    setState(() => _localErrors.remove(type.wire));
    try {
      final f = await _picker.pickImage(source: source, maxWidth: 2000, maxHeight: 2000, imageQuality: 85);
      if (f == null) return;
      final bytes = await f.readAsBytes();
      final ext = f.name.contains('.') ? f.name.split('.').last.toLowerCase() : '';
      String? error;
      if (!VerificationPolicy.allowedExtensions.contains(ext)) {
        error = 'Format non pris en charge. Utilisez JPG, PNG ou WebP.';
      } else if (bytes.isEmpty) {
        error = 'Le fichier choisi est vide.';
      } else if (bytes.length > VerificationPolicy.maxFileBytes) {
        error = 'Ce fichier est trop volumineux. Choisissez un fichier plus petit.';
      }
      if (error != null) {
        if (mounted) setState(() => _localErrors[type.wire] = error!);
        return;
      }
      final list = _files[type] ?? const <VerificationFile>[];
      if (list.length >= VerificationPolicy.maxFilesPerDocumentType) return;
      if (mounted) {
        setState(() => _files[type] = [
              ...list,
              VerificationFile(documentType: type, fileName: f.name, bytes: bytes, mimeType: VerificationPolicy.mimeTypeFor(ext)),
            ]);
      }
    } catch (_) {
      if (mounted) setState(() => _localErrors[type.wire] = 'Impossible de charger le fichier.');
    }
  }

  Map<String, dynamic> _data({Property? property}) => switch (widget.targetType) {
        VerificationTargetType.user => {'fullName': _name.text, 'phone': _phone.text},
        VerificationTargetType.owner => {
            'fullName': _name.text,
            'phone': _phone.text,
            if (_propertyRef.text.trim().isNotEmpty) 'propertyReference': _propertyRef.text,
          },
        VerificationTargetType.agent => {
            'fullName': _name.text,
            'phone': _phone.text,
            if (_agencyName.text.trim().isNotEmpty) 'agencyName': _agencyName.text,
            if (_agencyAddress.text.trim().isNotEmpty) 'agencyAddress': _agencyAddress.text,
          },
        VerificationTargetType.property => {
            'propertyTitle': property?.title ?? '',
            'city': property?.city ?? property?.governorate ?? '',
            'locationProvided': property?.hasCoordinates ?? false,
            'listingInformationProvided':
                property != null && property.title.trim().isNotEmpty && property.description.trim().isNotEmpty && property.price > 0,
            'photoCount': property?.images.length ?? 0,
          },
      };

  Future<void> _submit({required bool isAgency, Property? property}) async {
    final submission = VerificationSubmission(
      targetType: widget.targetType,
      targetId: widget.targetId,
      submittedData: _data(property: property),
      files: [for (final l in _files.values) ...l],
      isAgency: isAgency,
    );
    final ok = await ref.read(verificationFormProvider.notifier).submit(submission);
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    if (ok) {
      messenger.showSnackBar(const SnackBar(content: Text('Votre demande a été envoyée pour examen.')));
      context.pop();
    } else {
      final f = ref.read(verificationFormProvider).failure;
      if (f != null && f.fieldErrors.isEmpty) messenger.showSnackBar(SnackBar(content: Text(f.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    _prefill();
    final type = widget.targetType;
    final uid = ref.watch(currentUserProvider)?.id;
    final existing = ref.watch(verificationProvider(type.docId(widget.targetId)));
    final form = ref.watch(verificationFormProvider);
    final errors = {...form.fieldErrors, ..._localErrors};

    // Agency fields only for an agency profile.
    final isAgency = type == VerificationTargetType.agent && (ref.watch(agentProfileStreamProvider).value?.isAgency ?? false);

    // The listing being verified (owner / agent of the listing only).
    Property? property;
    if (type == VerificationTargetType.property) {
      final mine = ref.watch(myListingsProvider).value ?? const <Property>[];
      for (final p in mine) {
        if (p.id == widget.targetId) property = p;
      }
    }

    final title = '${type.label} verification';
    if (uid == null) {
      return Scaffold(appBar: AppBar(title: Text(title)), body: const AgentEmptyView(icon: Icons.lock_outline, message: 'Veuillez vous connecter.'));
    }
    if (type != VerificationTargetType.property && widget.targetId != uid) {
      return Scaffold(
        appBar: AppBar(title: Text(title)),
        body: AgentErrorView(message: const VerificationFailure(VerificationFailureType.permissionDenied).message),
      );
    }

    return existing.when(
      loading: () => Scaffold(appBar: AppBar(title: Text(title)), body: const AgentLoading()),
      error: (e, _) => Scaffold(
        appBar: AppBar(title: Text(title)),
        body: AgentErrorView(
          message: e is VerificationFailure ? e.message : const VerificationFailure(VerificationFailureType.unknown).message,
          onRetry: () => ref.invalidate(verificationProvider(type.docId(widget.targetId))),
        ),
      ),
      data: (record) {
        final status = record?.effectiveStatus() ?? VerificationStatus.notSubmitted;
        if (!VerificationStateMachine.canSubmit(status)) {
          return Scaffold(
            appBar: AppBar(title: Text(title)),
            body: AgentEmptyView(icon: Icons.info_outline, message: status.nextStep),
          );
        }
        if (type == VerificationTargetType.property && property == null) {
          return Scaffold(
            appBar: AppBar(title: Text(title)),
            body: ref.watch(myListingsProvider).isLoading
                ? const AgentLoading()
                : AgentEmptyView(
                    icon: Icons.home_work_outlined,
                    message: 'Seul l\'auteur d\'une annonce peut demander sa vérification.',
                  ),
          );
        }
        final busy = form.isBusy;
        final required = VerificationPolicy.requiredDocuments(type, isAgency: isAgency);
        return Scaffold(
          backgroundColor: AppColors.background,
          appBar: AppBar(title: Text(title)),
          body: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: ListView(padding: const EdgeInsets.fromLTRB(20, 16, 20, 32), children: [
                Row(children: [
                  VerificationStatusBadge(status: status),
                  if (record != null) ...[
                    const SizedBox(width: 10),
                    Text('Tentative ${record.attemptNumber + 1}', style: const TextStyle(color: AppColors.muted, fontSize: 12)),
                  ],
                ]),
                if (record?.rejectionReason != null) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: const Color(0xFFFDECEA), borderRadius: BorderRadius.circular(12)),
                    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Icon(Icons.error_outline_rounded, color: AppColors.error, size: 20),
                      const SizedBox(width: 8),
                      Expanded(child: Text('Votre demande doit être corrigée : ${record!.rejectionReason}')),
                    ]),
                  ),
                ],
                const SizedBox(height: 10),
                Text(VerificationPolicy.intro(type), style: const TextStyle(color: AppColors.muted, height: 1.4, fontSize: 13)),
                const SizedBox(height: 4),
                const Text(
                  'Vos documents ne servent qu\'à la vérification par l\'équipe DARNA.',
                  style: TextStyle(color: AppColors.muted, height: 1.4, fontSize: 13),
                ),
                if (type == VerificationTargetType.property) _PropertyChecklist(property: property!, error: errors['property']),
                if (type != VerificationTargetType.property) ...[
                  const SectionTitle('Vos informations'),
                  _field(_name, 'Nom complet', errors['fullName'], busy),
                  _field(_phone, 'Numéro de téléphone', errors['phone'], busy, keyboard: TextInputType.phone),
                  if (type == VerificationTargetType.owner)
                    _field(_propertyRef, 'Bien concerné (facultatif)', errors['propertyReference'], busy),
                  if (isAgency) ...[
                    _field(_agencyName, 'Nom de l\'agence', errors['agencyName'], busy),
                    _field(_agencyAddress, 'Adresse de l\'agence', errors['agencyAddress'], busy),
                  ],
                ],
                const SectionTitle('Documents'),
                for (final t in VerificationDocumentType.values.where(required.contains))
                  DocumentUploadField(
                    type: t,
                    required: true,
                    busy: busy,
                    files: _files[t] ?? const [],
                    error: errors[t.wire],
                    onAdd: (src) => _add(t, src),
                    onRemove: (i) => setState(() => _files[t] = [...?_files[t]]..removeAt(i)),
                  ),
                if (errors['documents'] != null)
                  Text(errors['documents']!, style: const TextStyle(color: AppColors.error, fontSize: 12)),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: busy ? null : () => _submit(isAgency: isAgency, property: property),
                  style: FilledButton.styleFrom(padding: const EdgeInsets.all(15)),
                  child: busy
                      ? const Row(mainAxisSize: MainAxisSize.min, children: [
                          SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
                          SizedBox(width: 10),
                          Text('Envoi en cours…'),
                        ])
                      : Text(record == null ? 'Envoyer pour vérification' : 'Renvoyer pour vérification'),
                ),
                if (form.phase == VerificationFormPhase.failed && form.fieldErrors.isNotEmpty)
                  const Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: Text('Veuillez remplir tous les champs obligatoires.', style: TextStyle(color: AppColors.error, fontSize: 12)),
                  ),
                TextButton(onPressed: () => context.pop(), child: const Text('Retour')),
              ]),
            ),
          ),
        );
      },
    );
  }

  Widget _field(TextEditingController c, String label, String? error, bool busy, {TextInputType? keyboard}) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: TextField(
          controller: c,
          enabled: !busy,
          keyboardType: keyboard,
          decoration: InputDecoration(labelText: label, errorText: error, filled: true, fillColor: Colors.white),
        ),
      );
}

/// What a reviewer will check on the listing, taken from the listing itself.
class _PropertyChecklist extends StatelessWidget {
  const _PropertyChecklist({required this.property, this.error});

  final Property property;
  final String? error;

  @override
  Widget build(BuildContext context) {
    final p = property;
    final rows = <(String, bool)>[
      ('Localisation complète', p.hasCoordinates),
      ('Informations de l\'annonce', p.title.trim().isNotEmpty && p.description.trim().isNotEmpty && p.price > 0),
      ('Au moins une photo (${p.images.length})', p.images.isNotEmpty),
    ];
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      SectionTitle('Annonce : ${p.title}'),
      for (final r in rows)
        Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Row(children: [
            Icon(r.$2 ? Icons.check_circle : Icons.cancel, size: 18, color: r.$2 ? AppColors.success : AppColors.error),
            const SizedBox(width: 8),
            Text(r.$1),
          ]),
        ),
      if (error != null) Padding(padding: const EdgeInsets.only(top: 4), child: Text(error!, style: const TextStyle(color: AppColors.error, fontSize: 12))),
      const SizedBox(height: 4),
      const Text(
        'La vérification porte sur cette annonce et les contrôles effectués. Une modification importante peut demander une nouvelle vérification.',
        style: TextStyle(fontSize: 12, color: AppColors.muted, height: 1.35),
      ),
    ]);
  }
}
