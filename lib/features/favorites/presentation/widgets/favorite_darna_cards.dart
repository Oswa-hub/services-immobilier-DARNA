import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/routes.dart';
import '../../../properties/domain/entities/property.dart';
import '../../../property_discovery/presentation/widgets/darna_property_cards.dart';
import '../../providers/favorite_providers.dart';
import '../favorite_feedback.dart';

/// [FeaturedPropertyCard] (Home "Biens en vedette") wired to the favorites module.
class FavoriteFeaturedPropertyCard extends ConsumerWidget {
  const FavoriteFeaturedPropertyCard({super.key, required this.property, this.width = 290, this.onTap});

  final Property property;
  final double width;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) => FeaturedPropertyCard(
        property: property,
        width: width,
        isFavorite: ref.watch(isFavoriteProvider(property.id)),
        onTap: onTap ?? () => context.push(Routes.propertyDetails(property.id)),
        onFavoriteTap: () => toggleFavoriteWithFeedback(context, ref, property.id),
      );
}

/// [PropertyRowCard] (Home "Près de vous" list) wired to the favorites module.
class FavoritePropertyRowCard extends ConsumerWidget {
  const FavoritePropertyRowCard({super.key, required this.property, this.onTap});

  final Property property;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) => PropertyRowCard(
        property: property,
        isFavorite: ref.watch(isFavoriteProvider(property.id)),
        onTap: onTap ?? () => context.push(Routes.propertyDetails(property.id)),
        onFavoriteTap: () => toggleFavoriteWithFeedback(context, ref, property.id),
      );
}
