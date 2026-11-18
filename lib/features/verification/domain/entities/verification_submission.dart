import 'dart:typed_data';

import 'verification_enums.dart';

/// One picked file, before it is sent to private storage.
class VerificationFile {
  const VerificationFile({
    required this.documentType,
    required this.fileName,
    required this.bytes,
    required this.mimeType,
  });

  final VerificationDocumentType documentType;
  final String fileName;
  final Uint8List bytes;
  final String mimeType;

  int get sizeBytes => bytes.length;
  String get extension => fileName.contains('.') ? fileName.split('.').last.toLowerCase() : '';
}

/// Everything the applicant provides (spec §11.1 `createVerificationRequest`).
class VerificationSubmission {
  const VerificationSubmission({
    required this.targetType,
    required this.targetId,
    required this.submittedData,
    required this.files,
    this.isAgency = false,
  });

  final VerificationTargetType targetType;
  final String targetId;
  final Map<String, dynamic> submittedData;
  final List<VerificationFile> files;

  /// Agency profiles also owe the agency document and agency fields.
  final bool isAgency;
}
