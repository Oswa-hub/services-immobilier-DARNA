import '../../publishing/domain/publishing_config.dart';

/// Module 17 — platform settings, stored in ONE document: `settings/platform`.
///
/// Everyone may read it (the app needs it before sign-in: legal pages, limits);
/// only an administrator may write it (firestore.rules validates every field).
/// When the document does not exist yet, [PlatformSettings.defaults] applies,
/// so the app never depends on an admin having filled it in.
class PlatformSettings {
  const PlatformSettings({
    this.maxImages = PublishingConfig.maxPhotos,
    this.maxImageSizeMb = 5,
    this.listingExpirationDays = 90,
    this.requireListingReview = true,
    this.announcementsEnabled = true,
    this.serverNotifications = false,
    this.supportedCurrencies = const ['TND'],
    this.termsText = '',
    this.privacyText = '',
    this.contactEmail = '',
    this.contactPhone = '',
    this.contactAddress = '',
    this.updatedAt,
    this.updatedBy,
  });

  // ---- limits -----------------------------------------------------------------

  /// Photos per listing. Cannot exceed [PublishingConfig.maxPhotos]: that hard
  /// cap is also enforced by the Firestore rules on listing creation.
  final int maxImages;

  /// Per photo, in MB. Cannot exceed the upload service limit (5 MB).
  final int maxImageSizeMb;

  /// A published listing expires after this many days (set on approval).
  final int listingExpirationDays;

  // ---- moderation / notifications -------------------------------------------------

  /// New listings wait in `pending_review` for an administrator (spec §25).
  /// Shown to the admin as the active rule; publishing always creates
  /// `pending_review` documents (enforced by rules).
  final bool requireListingReview;

  /// Admins may broadcast platform announcements.
  final bool announcementsEnabled;

  /// true once the Cloud Functions of Module 12 are deployed (Blaze plan): they
  /// then send moderation notifications, so the admin app must not write them
  /// too. false (Spark plan): the admin app writes them itself.
  final bool serverNotifications;

  // ---- market ---------------------------------------------------------------------
  final List<String> supportedCurrencies;

  // ---- legal / contact ------------------------------------------------------------
  final String termsText;
  final String privacyText;
  final String contactEmail;
  final String contactPhone;
  final String contactAddress;

  final DateTime? updatedAt;
  final String? updatedBy;

  static const defaults = PlatformSettings();

  // Bounds shared with firestore.rules (`validPlatformSettings`). Change together.
  static const minImages = 1;
  static const hardMaxImages = PublishingConfig.maxPhotos; // 10
  static const hardMaxImageSizeMb = 5;
  static const minExpirationDays = 7;
  static const maxExpirationDays = 365;
  static const maxLegalTextLength = 20000;
  static const allCurrencies = ['TND', 'EUR', 'USD'];

  /// Photo limit the publishing flow must apply.
  int get effectiveMaxImages => maxImages.clamp(minImages, hardMaxImages);
  int get effectiveMaxImageBytes => maxImageSizeMb.clamp(1, hardMaxImageSizeMb) * 1024 * 1024;

  bool get hasContact => contactEmail.isNotEmpty || contactPhone.isNotEmpty || contactAddress.isNotEmpty;

  /// Defensive: any missing / wrong value takes its default.
  factory PlatformSettings.fromMap(Map<String, dynamic>? d, {DateTime? updatedAt}) {
    if (d == null) return defaults;
    int readInt(String k, int fallback) {
      final v = d[k];
      return v is num ? v.toInt() : fallback;
    }

    bool readBool(String k, bool fallback) => d[k] is bool ? d[k] as bool : fallback;
    String readStr(String k) => d[k] is String ? (d[k] as String) : '';
    final currencies = d['supportedCurrencies'];
    final list = currencies is List ? [for (final c in currencies) if (c is String && c.isNotEmpty) c] : <String>[];

    return PlatformSettings(
      maxImages: readInt('maxImages', defaults.maxImages),
      maxImageSizeMb: readInt('maxImageSizeMb', defaults.maxImageSizeMb),
      listingExpirationDays: readInt('listingExpirationDays', defaults.listingExpirationDays),
      requireListingReview: readBool('requireListingReview', defaults.requireListingReview),
      announcementsEnabled: readBool('announcementsEnabled', defaults.announcementsEnabled),
      serverNotifications: readBool('serverNotifications', defaults.serverNotifications),
      supportedCurrencies: list.isEmpty ? defaults.supportedCurrencies : list,
      termsText: readStr('termsText'),
      privacyText: readStr('privacyText'),
      contactEmail: readStr('contactEmail'),
      contactPhone: readStr('contactPhone'),
      contactAddress: readStr('contactAddress'),
      updatedAt: updatedAt,
      updatedBy: d['updatedBy'] is String ? d['updatedBy'] as String : null,
    );
  }

  /// Fields written by the admin form (`updatedAt` / `updatedBy` added by the repository).
  Map<String, dynamic> toMap() => {
        'maxImages': maxImages,
        'maxImageSizeMb': maxImageSizeMb,
        'listingExpirationDays': listingExpirationDays,
        'requireListingReview': requireListingReview,
        'announcementsEnabled': announcementsEnabled,
        'serverNotifications': serverNotifications,
        'supportedCurrencies': supportedCurrencies,
        'termsText': termsText,
        'privacyText': privacyText,
        'contactEmail': contactEmail,
        'contactPhone': contactPhone,
        'contactAddress': contactAddress,
      };

  /// French error per invalid field (empty map = valid). Mirrors the rules.
  Map<String, String> validate() {
    final e = <String, String>{};
    if (maxImages < minImages || maxImages > hardMaxImages) {
      e['maxImages'] = 'Entre $minImages et $hardMaxImages photos.';
    }
    if (maxImageSizeMb < 1 || maxImageSizeMb > hardMaxImageSizeMb) {
      e['maxImageSizeMb'] = 'Entre 1 et $hardMaxImageSizeMb Mo.';
    }
    if (listingExpirationDays < minExpirationDays || listingExpirationDays > maxExpirationDays) {
      e['listingExpirationDays'] = 'Entre $minExpirationDays et $maxExpirationDays jours.';
    }
    if (supportedCurrencies.isEmpty || supportedCurrencies.any((c) => !allCurrencies.contains(c))) {
      e['supportedCurrencies'] = 'Choisissez au moins une devise.';
    }
    if (termsText.length > maxLegalTextLength) e['termsText'] = 'Texte trop long ($maxLegalTextLength caractères max).';
    if (privacyText.length > maxLegalTextLength) {
      e['privacyText'] = 'Texte trop long ($maxLegalTextLength caractères max).';
    }
    if (contactEmail.isNotEmpty && !RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(contactEmail)) {
      e['contactEmail'] = 'Adresse e-mail invalide.';
    }
    if (contactPhone.length > 30) e['contactPhone'] = '30 caractères maximum.';
    if (contactAddress.length > 200) e['contactAddress'] = '200 caractères maximum.';
    return e;
  }

  PlatformSettings copyWith({
    int? maxImages,
    int? maxImageSizeMb,
    int? listingExpirationDays,
    bool? requireListingReview,
    bool? announcementsEnabled,
    bool? serverNotifications,
    List<String>? supportedCurrencies,
    String? termsText,
    String? privacyText,
    String? contactEmail,
    String? contactPhone,
    String? contactAddress,
  }) =>
      PlatformSettings(
        maxImages: maxImages ?? this.maxImages,
        maxImageSizeMb: maxImageSizeMb ?? this.maxImageSizeMb,
        listingExpirationDays: listingExpirationDays ?? this.listingExpirationDays,
        requireListingReview: requireListingReview ?? this.requireListingReview,
        announcementsEnabled: announcementsEnabled ?? this.announcementsEnabled,
        serverNotifications: serverNotifications ?? this.serverNotifications,
        supportedCurrencies: supportedCurrencies ?? this.supportedCurrencies,
        termsText: termsText ?? this.termsText,
        privacyText: privacyText ?? this.privacyText,
        contactEmail: contactEmail ?? this.contactEmail,
        contactPhone: contactPhone ?? this.contactPhone,
        contactAddress: contactAddress ?? this.contactAddress,
        updatedAt: updatedAt,
        updatedBy: updatedBy,
      );
}
