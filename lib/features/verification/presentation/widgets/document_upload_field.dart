import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/theme/app_colors.dart';
import '../../domain/entities/verification_enums.dart';
import '../../domain/entities/verification_submission.dart';
import '../../domain/services/verification_policy.dart';

/// One document category: what it is, why it is asked, the picked files and the
/// add / remove actions. Used by the applicant form.
class DocumentUploadField extends StatelessWidget {
  const DocumentUploadField({
    super.key,
    required this.type,
    required this.files,
    required this.required,
    required this.busy,
    required this.onAdd,
    required this.onRemove,
    this.error,
  });

  final VerificationDocumentType type;
  final List<VerificationFile> files;
  final bool required;
  final bool busy;
  final String? error;
  final void Function(ImageSource source) onAdd;
  final void Function(int index) onRemove;

  @override
  Widget build(BuildContext context) {
    final full = files.length >= VerificationPolicy.maxFilesPerDocumentType;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: error == null ? AppColors.line : AppColors.error),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
            child: Text('${type.label}${required ? ' *' : ''}', style: const TextStyle(fontWeight: FontWeight.w800)),
          ),
          if (files.isNotEmpty) const Icon(Icons.check_circle, color: AppColors.success, size: 20),
        ]),
        const SizedBox(height: 4),
        Text(VerificationPolicy.whyRequested(type),
            style: const TextStyle(fontSize: 12, color: AppColors.muted, height: 1.35)),
        if (files.isNotEmpty) ...[
          const SizedBox(height: 10),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (var i = 0; i < files.length; i++)
              Stack(children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.memory(files[i].bytes, width: 72, height: 72, fit: BoxFit.cover),
                ),
                Positioned(
                  right: 0,
                  top: 0,
                  child: Semantics(
                    button: true,
                    label: 'Retirer le fichier ${i + 1}',
                    child: InkWell(
                      onTap: busy ? null : () => onRemove(i),
                      child: const CircleAvatar(
                        radius: 11,
                        backgroundColor: Colors.black54,
                        child: Icon(Icons.close, size: 14, color: Colors.white),
                      ),
                    ),
                  ),
                ),
              ]),
          ]),
        ],
        Wrap(spacing: 8, children: [
          TextButton.icon(
            onPressed: (busy || full) ? null : () => onAdd(ImageSource.camera),
            icon: const Icon(Icons.photo_camera_outlined, size: 18),
            label: const Text('Prendre une photo'),
          ),
          TextButton.icon(
            onPressed: (busy || full) ? null : () => onAdd(ImageSource.gallery),
            icon: const Icon(Icons.photo_library_outlined, size: 18),
            label: const Text('Choisir un fichier'),
          ),
        ]),
        if (error != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(error!, style: const TextStyle(color: AppColors.error, fontSize: 12)),
          ),
      ]),
    );
  }
}
