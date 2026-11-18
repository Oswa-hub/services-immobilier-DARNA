import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/verification_failure.dart';
import '../../../../core/services/cloudinary_service.dart';
import '../../../auth/providers/auth_provider.dart';
import '../../../properties/domain/entities/property.dart';
import '../../data/verification_document_link_service.dart';
import '../../data/verification_remote_data_source.dart';
import '../../data/verification_repository_impl.dart';
import '../../domain/entities/verification_enums.dart';
import '../../domain/entities/verification_record.dart';
import '../../domain/entities/verification_submission.dart';
import '../../domain/repositories/verification_repository.dart';

// ---- infrastructure (override in tests) -------------------------------------
final verificationRepositoryProvider = Provider<VerificationRepository>((ref) {
  final auth = ref.watch(firebaseAuthProvider);
  return VerificationRepositoryImpl(
    VerificationRemoteDataSource(ref.watch(firestoreProvider), auth),
    CloudinaryService(),
    VerificationDocumentLinkService(auth),
  );
});

String? _uid(Ref ref) => ref.watch(currentUserProvider)?.id;

// ---- applicant data (scoped to the signed-in user) ------------------------------
final myVerificationsProvider = StreamProvider.autoDispose<List<VerificationRecord>>((ref) {
  if (_uid(ref) == null) return const Stream.empty();
  return ref.watch(verificationRepositoryProvider).watchMyVerifications();
});

/// One request by id; `null` data = `not_submitted`.
final verificationProvider = StreamProvider.autoDispose.family<VerificationRecord?, String>((ref, id) {
  if (_uid(ref) == null) return const Stream.empty();
  return ref.watch(verificationRepositoryProvider).watchVerification(id);
});

final verificationHistoryProvider =
    StreamProvider.autoDispose.family<List<VerificationHistoryEntry>, String>((ref, id) {
  if (_uid(ref) == null) return const Stream.empty();
  return ref.watch(verificationRepositoryProvider).watchHistory(id);
});

/// Admin queue by status. The rules reject non-admins; the route guard hides it.
final verificationQueueProvider =
    StreamProvider.autoDispose.family<List<VerificationRecord>, VerificationStatus>((ref, status) {
  final user = ref.watch(currentUserProvider);
  if (user == null || !user.isAdmin) return const Stream.empty();
  return ref.watch(verificationRepositoryProvider).watchByStatus(status);
});

// ---- submit form -------------------------------------------------------------------
enum VerificationFormPhase { idle, submitting, success, failed }

class VerificationFormState {
  const VerificationFormState({this.phase = VerificationFormPhase.idle, this.failure});

  final VerificationFormPhase phase;
  final VerificationFailure? failure;

  bool get isBusy => phase == VerificationFormPhase.submitting;
  Map<String, String> get fieldErrors => failure?.fieldErrors ?? const {};
}

final verificationFormProvider =
    NotifierProvider<VerificationFormController, VerificationFormState>(VerificationFormController.new);

class VerificationFormController extends Notifier<VerificationFormState> {
  @override
  VerificationFormState build() => const VerificationFormState();

  void reset() => state = const VerificationFormState();

  /// Duplicate taps are ignored. Returns true on success.
  Future<bool> submit(VerificationSubmission submission) async {
    if (state.isBusy) return false;
    state = const VerificationFormState(phase: VerificationFormPhase.submitting);
    try {
      await ref.read(verificationRepositoryProvider).submit(submission);
      state = const VerificationFormState(phase: VerificationFormPhase.success);
      return true;
    } on VerificationFailure catch (e) {
      state = VerificationFormState(phase: VerificationFormPhase.failed, failure: e);
      return false;
    } catch (_) {
      state = const VerificationFormState(
          phase: VerificationFormPhase.failed, failure: VerificationFailure(VerificationFailureType.unknown));
      return false;
    }
  }
}

// ---- admin decisions ------------------------------------------------------------------
final verificationReviewProvider =
    NotifierProvider<VerificationReviewController, VerificationFormState>(VerificationReviewController.new);

class VerificationReviewController extends Notifier<VerificationFormState> {
  @override
  VerificationFormState build() => const VerificationFormState();

  Future<bool> _run(Future<void> Function(VerificationRepository repo) action) async {
    if (state.isBusy) return false;
    state = const VerificationFormState(phase: VerificationFormPhase.submitting);
    try {
      await action(ref.read(verificationRepositoryProvider));
      state = const VerificationFormState(phase: VerificationFormPhase.success);
      return true;
    } on VerificationFailure catch (e) {
      state = VerificationFormState(phase: VerificationFormPhase.failed, failure: e);
      return false;
    } catch (_) {
      state = const VerificationFormState(
          phase: VerificationFormPhase.failed, failure: VerificationFailure(VerificationFailureType.unknown));
      return false;
    }
  }

  Future<bool> approve(String id) => _run((r) => r.approve(id));
  Future<bool> reject(String id, String reason) => _run((r) => r.reject(id, reason));
  Future<bool> markExpired(String id) => _run((r) => r.markExpired(id));
}
