import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

import '../../../core/config/env.dart';
import '../../../core/errors/verification_failure.dart';

/// Asks the trusted backend (`backend/verificationDocumentUrl.ts`) for a
/// short-lived signed link to ONE private document (spec §13.2, §14.2).
///
/// The app never holds the Cloudinary secret, so it cannot sign links itself.
/// The backend re-checks that the caller is the applicant or an administrator
/// and that the document really belongs to that request.
class VerificationDocumentLinkService {
  VerificationDocumentLinkService(this._auth, {http.Client? client}) : _client = client ?? http.Client();

  final FirebaseAuth _auth;
  final http.Client _client;

  Future<Uri> link({required String verificationId, required String documentId}) async {
    if (!Env.verificationDocumentEndpointConfigured) {
      throw const VerificationFailure(VerificationFailureType.documentAccessFailed,
          detail: 'Document viewing is not configured yet.');
    }
    final token = await _auth.currentUser?.getIdToken();
    if (token == null) throw const VerificationFailure(VerificationFailureType.unauthenticated);
    try {
      final res = await _client
          .post(
            Uri.parse(Env.verificationDocumentEndpoint),
            headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'},
            body: jsonEncode({'verificationId': verificationId, 'documentId': documentId}),
          )
          .timeout(const Duration(seconds: 20));
      if (res.statusCode == 401 || res.statusCode == 403) {
        throw const VerificationFailure(VerificationFailureType.permissionDenied);
      }
      if (res.statusCode == 404) throw const VerificationFailure(VerificationFailureType.notFound);
      if (res.statusCode != 200) throw const VerificationFailure(VerificationFailureType.documentAccessFailed);
      final body = jsonDecode(res.body);
      final url = body is Map ? body['url'] : null;
      final uri = url is String ? Uri.tryParse(url) : null;
      if (uri == null || uri.scheme != 'https') {
        throw const VerificationFailure(VerificationFailureType.documentAccessFailed);
      }
      return uri;
    } on VerificationFailure {
      rethrow;
    } catch (_) {
      throw const VerificationFailure(VerificationFailureType.network);
    }
  }
}
