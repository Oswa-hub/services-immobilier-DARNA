import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../properties/domain/entities/property.dart';
import '../../domain/entities/property_type_rules.dart';
import '../../domain/services/listing_validator.dart';
import '../providers/publishing_provider.dart';
import 'publish_widgets.dart';

IconData _icon(PropertyType t) => switch (t) {
      PropertyType.apartment => Icons.apartment,
      PropertyType.villa => Icons.villa,
      PropertyType.house => Icons.house,
      PropertyType.duplex => Icons.home_work,
      PropertyType.triplex => Icons.domain,
      PropertyType.land => Icons.landscape,
      PropertyType.office => Icons.business,
      PropertyType.commercial => Icons.storefront,
      PropertyType.industrial => Icons.factory,
      PropertyType.other => Icons.home,
    };

/// Steps 1 + 2 of the journey: property type and sale / rent.
class PropertyTypeStep extends ConsumerWidget {
  const PropertyTypeStep({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(publishingControllerProvider);
    final c = ref.read(publishingControllerProvider.notifier);
    final d = s.draft;

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const StepHeader(title: 'Que publiez-vous ?', subtitle: 'Choisissez le type de bien et le type d\'offre.'),
      GridView(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        // Height follows the phone's text size (French labels are longer).
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          mainAxisExtent: 56 * MediaQuery.textScalerOf(context).scale(1).clamp(1.0, 1.8),
        ),
        children: [
          for (final t in publishablePropertyTypes)
            ChoiceTile(label: t.label, icon: _icon(t), selected: d.propertyType == t, onTap: () => c.setPropertyType(t)),
        ],
      ),
      FieldError(s.errors[ListingField.propertyType]),
      const SizedBox(height: 24),
      const Text('Offre', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
      const SizedBox(height: 10),
      Row(children: [
        for (final t in TransactionType.values) ...[
          Expanded(
            child: ChoiceTile(
              label: t.label,
              icon: t == TransactionType.buy ? Icons.sell_outlined : Icons.key_outlined,
              selected: d.transactionType == t,
              onTap: () => c.setTransactionType(t),
            ),
          ),
          if (t != TransactionType.values.last) const SizedBox(width: 10),
        ],
      ]),
      FieldError(s.errors[ListingField.transactionType]),
    ]);
  }
}
