import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/providers/auth_provider.dart';
import '../../../properties/domain/entities/amenity.dart';
import '../../data/catalog_repository.dart';
import '../../domain/catalog.dart';

/// Override in tests with a fake.
final catalogRepositoryProvider = Provider<CatalogRepository>(
  (ref) => FirestoreCatalogRepository(ref.watch(firestoreProvider)),
);

/// Live list, for the admin editor (shows loading / error).
final catalogStreamProvider = StreamProvider.family<List<CatalogItem>, CatalogKey>(
  (ref, key) => ref.watch(catalogRepositoryProvider).watch(key),
);

/// What the app reads: always a list (defaults while loading or on error).
final catalogProvider = Provider.family<List<CatalogItem>, CatalogKey>(
  (ref, key) => ref.watch(catalogStreamProvider(key)).maybeWhen(
        data: (items) => items,
        orElse: () => CatalogEditor.reconcile(key, key.defaults),
      ),
);

/// Active labels only, in admin order (pickers, filters, report reasons...).
final activeCatalogProvider = Provider.family<List<CatalogItem>, CatalogKey>(
  (ref, key) => [for (final i in ref.watch(catalogProvider(key))) if (i.active) i],
);

/// Amenities offered when publishing: admin order and labels, hidden ones out.
/// Ids stay the [Amenity] enum names (what listings store and search filters on).
final amenityOptionsProvider = Provider<List<({Amenity amenity, String label})>>((ref) => [
      for (final item in ref.watch(activeCatalogProvider(CatalogKey.amenities)))
        if (Amenity.tryParse(item.id) case final a?) (amenity: a, label: item.label),
    ]);
