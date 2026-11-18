/// Spec §11.3 error codes.
enum VerificationFailureType {
  unauthenticated,
  permissionDenied,
  notFound,
  invalidTargetType,
  validationFailed,
  invalidStatusTransition,
  alreadyReviewed,
  documentUploadFailed,
  documentAccessFailed,
  network,
  unknown,
}

/// The only text a user ever sees. Raw Firebase / server messages are never
/// exposed (spec §18).
class VerificationFailure implements Exception {
  const VerificationFailure(this.type, {this.fieldErrors = const {}, this.detail});

  final VerificationFailureType type;

  /// Field key -> message, only for [VerificationFailureType.validationFailed].
  final Map<String, String> fieldErrors;

  /// Safe, human-readable hint (never a raw exception message).
  final String? detail;

  String get message => switch (type) {
        VerificationFailureType.unauthenticated => 'Please sign in again.',
        VerificationFailureType.permissionDenied => 'You do not have permission to perform this action.',
        VerificationFailureType.notFound => 'This verification request could not be found.',
        VerificationFailureType.invalidTargetType => 'This type of verification is not supported.',
        VerificationFailureType.validationFailed => detail ?? 'Please complete all required fields.',
        VerificationFailureType.invalidStatusTransition =>
          detail ?? 'This action is not allowed for the current status.',
        VerificationFailureType.alreadyReviewed => 'This request has already been reviewed. Refresh the page.',
        VerificationFailureType.documentUploadFailed => 'The document could not be uploaded. Please try again.',
        VerificationFailureType.documentAccessFailed => 'The document could not be opened. Please try again.',
        VerificationFailureType.network => 'We could not reach the server. Check your connection and try again.',
        VerificationFailureType.unknown => 'Something went wrong. Please try again.',
      };

  @override
  String toString() => 'VerificationFailure($type${detail == null ? '' : ', $detail'})';
}
