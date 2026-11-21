import '../../../properties/domain/entities/property.dart';
import '../../../properties/domain/listing_lifecycle.dart';

/// What an agent may do with one of THEIR listings, by status (spec §5.5).
/// This only drives the UI and the client guard. The real enforcement is in
/// Firestore Rules (`backend/firestore.rules`): never trust it alone.
///
/// The lifecycle is the SHARED one (Property.status). The agent module never
/// invents another status system and never sets a moderation status
/// (published / rejected / suspended / expired): administrators do.
class ListingPolicy {
  ListingPolicy._();

  static bool canViewPublic(PropertyStatus s) => s == PropertyStatus.published;

  /// Editing happens in the publishing module (Module 08).
  static bool canEdit(PropertyStatus s) => switch (s) {
        PropertyStatus.draft || PropertyStatus.rejected || PropertyStatus.published => true,
        _ => false,
      };

  /// draft | rejected -> pending_review (after the shared validation).
  /// Driven by the shared lifecycle table (mirrors the Firestore rules).
  static bool canSubmit(PropertyStatus s) => canMove(s, PropertyStatus.pendingReview);

  /// -> removed. Allowed from every non-final, non-suspended state.
  static bool canWithdraw(PropertyStatus s) => canMove(s, PropertyStatus.removed);

  static String statusLabel(PropertyStatus s) => switch (s) {
        PropertyStatus.draft => 'Brouillon',
        PropertyStatus.pendingReview => 'En attente',
        PropertyStatus.published => 'Publiées',
        PropertyStatus.rejected => 'Refusées',
        PropertyStatus.suspended => 'Suspendues',
        PropertyStatus.removed => 'Retirée',
        PropertyStatus.expired => 'Expirées',
      };

  /// Short hint shown on the card for states that need the agent's attention.
  static String? statusHint(PropertyStatus s) => switch (s) {
        PropertyStatus.rejected => 'À corriger avant de la renvoyer.',
        PropertyStatus.suspended => 'Suspendue par la modération. Contactez le support.',
        PropertyStatus.pendingReview => 'En attente d\'un administrateur.',
        PropertyStatus.expired => 'N\'est plus visible par les utilisateurs.',
        _ => null,
      };
}

/// The shared Property Publishing validation (spec §10.2), re-checked before an
/// agent submits a draft / rejected listing. Never weaker than Module 08.
class ListingSubmissionCheck {
  ListingSubmissionCheck._();

  /// Empty list == the listing may be submitted.
  static List<String> problems(Property p) => [
        if (p.title.trim().isEmpty) 'Le titre est obligatoire.',
        if (p.description.trim().isEmpty) 'La description est obligatoire.',
        if (p.price <= 0) 'Le prix doit être supérieur à zéro.',
        if ((p.surface ?? 0) <= 0) 'La surface doit être supérieure à zéro.',
        if (p.images.isEmpty) 'Ajoutez au moins une photo.',
        if (p.governorate.trim().isEmpty) 'Une localisation valide est obligatoire.',
      ];
}