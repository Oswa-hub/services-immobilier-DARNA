import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../../auth/domain/entities/auth_user.dart';
import '../../properties/data/property_mapper.dart';
import '../../properties/domain/entities/property.dart';
import '../domain/entities/listing_draft.dart';
import '../domain/publishing_failure.dart';
import '../domain/repositories/listing_repository.dart';
import 'listing_remote_data_source.dart';
import 'photo_uploader.dart';
import 'property_write_mapper.dart';

class ListingRepositoryImpl implements ListingRepository {
  ListingRepositoryImpl(this._ds, this._uploader);

  final ListingRemoteDataSource _ds;
  final PhotoUploader _uploader;

  static const _writeTimeout = Duration(seconds: 30);

  @override
  String newListingId() => _ds.newId();

  @override
  Future<String> uploadPhoto({required String listingId, required ListingPhoto photo}) async {
    try {
      final url = await _uploader.upload(photo, folder: 'properties/$listingId');
      // Never keep a URL that is not a real HTTPS upload result (spec §8.3).
      if (!url.startsWith('https://')) throw const PublishingFailure(PublishingFailureType.uploadFailed);
      return url;
    } on PublishingFailure {
      rethrow;
    } catch (e) {
      debugPrint('Photo upload failed: $e');
      throw const PublishingFailure(PublishingFailureType.uploadFailed);
    }
  }

  @override
  Future<void> createListing({
    required String listingId,
    required ListingDraft draft,
    required AuthUser user,
    required List<String> imageUrls,
  }) async {
    final data = PropertyWriteMapper.newListing(draft: draft, user: user, imageUrls: imageUrls);
    try {
      await _ds.create(listingId, data).timeout(_writeTimeout);
    } on FirebaseException catch (e) {
      debugPrint('Create listing failed [${e.code}]: ${e.message}');
      // A retry of a write that actually succeeded is an UPDATE for the rules, which
      // owners cannot do. If the document is already ours, the submission worked.
      if (await _alreadyCreated(listingId, user.id)) return;
      throw PublishingFailure(switch (e.code) {
        'permission-denied' => PublishingFailureType.permissionDenied,
        'unavailable' || 'deadline-exceeded' || 'network-request-failed' => PublishingFailureType.network,
        _ => PublishingFailureType.unknown,
      });
    } on TimeoutException {
      if (await _alreadyCreated(listingId, user.id)) return;
      throw const PublishingFailure(PublishingFailureType.network);
    } catch (e, st) {
      debugPrint('Unexpected create error: $e\n$st');
      throw const PublishingFailure(PublishingFailureType.unknown);
    }
  }

  @override
  Future<Property?> loadListing(String listingId) async {
    try {
      final data = await _ds.read(listingId);
      return data == null ? null : PropertyMapper.tryFromMap(listingId, data);
    } catch (e) {
      debugPrint('Load listing for edit failed: $e');
      return null;
    }
  }

  @override
  Future<void> updateListing({
    required String listingId,
    required ListingDraft draft,
    required List<String> imageUrls,
  }) async {
    final data = PropertyWriteMapper.editedListing(draft: draft, imageUrls: imageUrls);
    try {
      // An update is idempotent: a retry writes the same values again.
      await _ds.update(listingId, data).timeout(_writeTimeout);
    } on FirebaseException catch (e) {
      debugPrint('Update listing failed [${e.code}]: ${e.message}');
      throw PublishingFailure(switch (e.code) {
        'permission-denied' => PublishingFailureType.permissionDenied,
        'not-found' => PublishingFailureType.unknown,
        'unavailable' || 'deadline-exceeded' || 'network-request-failed' => PublishingFailureType.network,
        _ => PublishingFailureType.unknown,
      });
    } on TimeoutException {
      throw const PublishingFailure(PublishingFailureType.network);
    } catch (e, st) {
      debugPrint('Unexpected update error: $e\n$st');
      throw const PublishingFailure(PublishingFailureType.unknown);
    }
  }

  Future<bool> _alreadyCreated(String id, String uid) async {
    try {
      return await _ds.existsOwnedBy(id, uid).timeout(const Duration(seconds: 8));
    } catch (_) {
      return false;
    }
  }
}
