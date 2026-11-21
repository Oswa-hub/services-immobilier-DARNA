import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../content/presentation/providers/catalog_providers.dart'; // Module 16
import '../../../properties/domain/entities/amenity.dart';
import '../../domain/services/listing_validator.dart';
import '../providers/publishing_provider.dart';
import 'publish_widgets.dart';

/// Step 7: multi-select. The stored value is `Amenity.id` (the enum name), which
/// is what Search filters on and Details displays.
class AmenitiesStep extends ConsumerWidget {
  const AmenitiesStep({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(publishingControllerProvider);
    final c = ref.read(publishingControllerProvider.notifier);
    // Module 16: order, labels and visibility come from the admin catalog.
    // An amenity hidden later stays visible here if this draft already uses it.
    final options = ref.watch(amenityOptionsProvider);
    final shown = {for (final o in options) o.amenity};
    final chips = [
      ...options,
      for (final a in Amenity.values)
        if (!shown.contains(a) && s.draft.amenities.contains(a.id)) (amenity: a, label: a.label),
    ];

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const StepHeader(title: 'Équipements', subtitle: 'Choisissez tout ce que le bien propose. Vous pouvez passer cette étape.'),
      Wrap(spacing: 8, runSpacing: 8, children: [
        for (final o in chips)
          FilterChip(
            label: Text(o.label),
            selected: s.draft.amenities.contains(o.amenity.id),
            onSelected: (_) => c.toggleAmenity(o.amenity.id),
          ),
      ]),
      FieldError(s.errors[ListingField.amenities]),
    ]);
  }
}
