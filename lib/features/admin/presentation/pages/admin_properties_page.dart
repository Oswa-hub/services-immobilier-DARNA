import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../content/domain/catalog.dart';
import '../../../content/presentation/providers/catalog_providers.dart';
import '../../../properties/domain/entities/property.dart';
import '../../domain/admin_policy.dart';
import '../providers/admin_providers.dart';
import '../widgets/admin_widgets.dart';

/// Module 15 — `/admin/properties` (spec §40): view, search, filter, approve,
/// reject, suspend, restore, remove. Default view = the moderation queue.
class AdminPropertiesPage extends ConsumerStatefulWidget {
  const AdminPropertiesPage({super.key});

  @override
  ConsumerState<AdminPropertiesPage> createState() => _AdminPropertiesPageState();
}

class _AdminPropertiesPageState extends ConsumerState<AdminPropertiesPage> {
  PropertyStatus? _status = PropertyStatus.pendingReview;
  String _query = '';

  List<Property> _filter(List<Property> all) {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return all;
    return [
      for (final p in all)
        if (p.title.toLowerCase().contains(q) ||
            p.governorate.toLowerCase().contains(q) ||
            (p.city ?? '').toLowerCase().contains(q) ||
            p.id == _query.trim() ||
            p.ownerId == _query.trim())
          p,
    ];
  }

  @override
  Widget build(BuildContext context) {
    final props = ref.watch(adminPropertiesProvider(_status));
    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
        child: TextField(
          decoration: const InputDecoration(
            prefixIcon: Icon(Icons.search),
            hintText: 'Titre, ville, gouvernorat, identifiant ou propriétaire',
            border: OutlineInputBorder(),
            isDense: true,
          ),
          onChanged: (v) => setState(() => _query = v),
        ),
      ),
      SizedBox(
        height: 48,
        child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 12), children: [
          for (final s in <PropertyStatus?>[PropertyStatus.pendingReview, null, ...PropertyStatus.values.where((x) => x != PropertyStatus.pendingReview)])
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: ChoiceChip(
                label: Text(s == null ? 'Toutes' : propertyStatusLabel(s)),
                selected: _status == s,
                onSelected: (_) => setState(() => _status = s),
              ),
            ),
        ]),
      ),
      Expanded(
        child: props.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => AdminMessage.error(e, onRetry: () => ref.invalidate(adminPropertiesProvider(_status))),
          data: (all) {
            final list = _filter(all);
            if (list.isEmpty) {
              return AdminMessage(
                icon: Icons.inventory_2_outlined,
                text: _status == PropertyStatus.pendingReview ? 'Aucune annonce à valider 🎉' : 'Aucune annonce.',
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.only(bottom: 24),
              itemCount: list.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (_, i) {
                final p = list[i];
                return ListTile(
                  tileColor: Colors.white,
                  leading: _Thumb(url: p.images.isEmpty ? null : p.images.first),
                  title: Text(p.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                  subtitle: Text(
                    '${[p.city, p.governorate].whereType<String>().join(', ')} · ${fmtPrice(p.price, p.currency)} · ${fmtDate(p.createdAt)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: StatusChip(propertyStatusLabel(p.status), propertyStatusColor(p.status)),
                  onTap: () => showModalBottomSheet<void>(
                    context: context,
                    isScrollControlled: true,
                    showDragHandle: true,
                    builder: (_) => AdminPropertySheet(property: p),
                  ),
                );
              },
            );
          },
        ),
      ),
    ]);
  }
}

class _Thumb extends StatelessWidget {
  const _Thumb({this.url});
  final String? url;

  @override
  Widget build(BuildContext context) => ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: SizedBox(
          width: 52,
          height: 52,
          child: url == null
              ? const ColoredBox(color: AppColors.chip, child: Icon(Icons.home_outlined, color: AppColors.muted))
              : Image.network(
                  url!,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) =>
                      const ColoredBox(color: AppColors.chip, child: Icon(Icons.broken_image_outlined, color: AppColors.muted)),
                ),
        ),
      );
}

/// Details + moderation actions for one listing.
class AdminPropertySheet extends ConsumerWidget {
  const AdminPropertySheet({super.key, required this.property});

  final Property property;

  Future<void> _act(BuildContext context, WidgetRef ref, ModerationAction action) async {
    final reason = await askAdminConfirmation(
      context,
      title: '${action.label} l’annonce ?',
      message: '« ${property.title} » passera au statut « ${propertyStatusLabel(action.to)} ».',
      confirmLabel: action.label,
      needsReason: action.needsReason,
      destructive: action != ModerationAction.approve && action != ModerationAction.restore,
    );
    if (reason == null || !context.mounted) return;
    final failure = await ref.read(adminActionsProvider).moderate(
          property,
          action,
          reason: action.needsReason ? reason : null,
        );
    if (!context.mounted) return;
    showAdminResult(context, failure, 'Annonce mise à jour.');
    if (failure == null) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = property;
    final actions = AdminPolicy.moderationActions(p.status);
    final types = ref.watch(catalogProvider(CatalogKey.propertyTypes));
    final typeLabel = types.where((t) => t.id == p.propertyType.name).map((t) => t.label).firstOrNull ?? p.propertyType.name;

    return SafeArea(
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.75,
        maxChildSize: 0.95,
        builder: (_, controller) => ListView(controller: controller, padding: const EdgeInsets.fromLTRB(20, 0, 20, 20), children: [
          Text(p.title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.navy)),
          const SizedBox(height: 6),
          Row(children: [
            StatusChip(propertyStatusLabel(p.status), propertyStatusColor(p.status)),
            const SizedBox(width: 8),
            Text(fmtPrice(p.price, p.currency), style: const TextStyle(fontWeight: FontWeight.w800)),
          ]),
          if (p.images.isNotEmpty) ...[
            const SizedBox(height: 12),
            SizedBox(
              height: 110,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: p.images.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (_, i) => ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.network(p.images[i], width: 150, fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => const SizedBox(width: 150, child: Icon(Icons.broken_image_outlined))),
                ),
              ),
            ),
          ],
          const SizedBox(height: 12),
          _Line('Type', '$typeLabel · ${p.transactionType == TransactionType.rent ? 'Location' : 'Vente'}'),
          _Line('Lieu', [p.area, p.city, p.governorate].whereType<String>().join(', ')),
          if (p.surface != null) _Line('Surface', '${p.surface} m²'),
          _Line('Propriétaire', '${p.ownerName ?? '—'} (${p.ownerId})'),
          if (p.agentId != null) _Line('Agent', p.agentId!),
          _Line('Créée le', fmtDate(p.createdAt, time: true)),
          _Line('Publiée le', fmtDate(p.publishedAt, time: true)),
          _Line('Vues / favoris', '${p.views} / ${p.favoritesCount}'),
          const SizedBox(height: 8),
          Text(p.description, style: const TextStyle(height: 1.4)),
          const Divider(height: 28),
          if (p.status == PropertyStatus.published)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () {
                  Navigator.of(context).pop();
                  context.push(Routes.propertyDetails(p.id));
                },
                icon: const Icon(Icons.open_in_new),
                label: const Text('Voir la page publique'),
              ),
            ),
          if (actions.isEmpty)
            const Text('Aucune action de modération pour ce statut.', style: TextStyle(color: AppColors.muted))
          else
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (final a in actions)
                a == ModerationAction.approve || a == ModerationAction.restore
                    ? FilledButton(onPressed: () => _act(context, ref, a), child: Text(a.label))
                    : OutlinedButton(
                        style: OutlinedButton.styleFrom(foregroundColor: AppColors.error),
                        onPressed: () => _act(context, ref, a),
                        child: Text(a.label),
                      ),
            ]),
        ]),
      ),
    );
  }
}

class _Line extends StatelessWidget {
  const _Line(this.label, this.value);
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(width: 120, child: Text(label, style: const TextStyle(color: AppColors.muted))),
          Expanded(child: SelectableText(value)),
        ]),
      );
}
