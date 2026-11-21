import '../../../auth/domain/entities/auth_user.dart';
import '../../../properties/domain/entities/property.dart';
import '../entities/listing_draft.dart';

/// Write side of properties (Module 08). Throws [PublishingFailure] only.
/// The read side stays in `PropertyRepository` (Module 05).
abstract interface class ListingRepository {
  /// Firestore-generated id, created BEFORE uploading so a retry reuses the same
  /// document id (no duplicate listing on a second tap).
  String newListingId();

  /// Uploads one photo and returns its HTTPS URL.
  Future<String> uploadPhoto({required String listingId, required ListingPhoto photo});

  /// Creates `properties/{listingId}` with status `pending_review`.
  Future<void> createListing({
    required String listingId,
    required ListingDraft draft,
    required AuthUser user,
    required List<String> imageUrls,
  });

  /// Updates `properties/{listingId}` with the edited content and sends it back
  /// to moderation (`pending_review`).
  Future<void> updateListing({
    required String listingId,
    required ListingDraft draft,
    required List<String> imageUrls,
  });

  /// Reads a listing for edit mode, whatever its status (the rules let its owner
  /// or agent read it). Null when it does not exist or cannot be read.
  Future<Property?> loadListing(String listingId);
}
