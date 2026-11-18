import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../content/domain/catalog.dart';
import '../../../content/presentation/providers/catalog_providers.dart';
import '../providers/admin_providers.dart';
import '../widgets/admin_widgets.dart';

const _monthNames = ['janv.', 'févr.', 'mars', 'avr.', 'mai', 'juin', 'juil.', 'août', 'sept.', 'oct.', 'nov.', 'déc.'];

String _monthLabel(String key) {
  final parts = key.split('-');
  final m = int.tryParse(parts.length == 2 ? parts[1] : '') ?? 0;
  return m >= 1 && m <= 12 ? '${_monthNames[m - 1]} ${parts[0].substring(2)}' : key;
}

/// Module 15 — `/admin/analytics` (spec §42), computed from the most recent
/// documents (up to 1000 listings and 1000 users).
class AdminAnalyticsPage extends ConsumerWidget {
  const AdminAnalyticsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(adminAnalyticsProvider);
    final types = {for (final t in ref.watch(catalogProvider(CatalogKey.propertyTypes))) t.id: t.label};

    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => AdminMessage.error(e, onRetry: () => ref.invalidate(adminAnalyticsProvider)),
      data: (a) => RefreshIndicator(
        onRefresh: () => ref.refresh(adminAnalyticsProvider.future),
        child: ListView(padding: const EdgeInsets.all(16), children: [
          Text(
            'Calculé sur ${a.sampledProperties} annonces et ${a.sampledUsers} utilisateurs (les plus récents).',
            style: const TextStyle(color: AppColors.muted, fontSize: 12.5),
          ),
          const SizedBox(height: 10),
          Wrap(spacing: 10, runSpacing: 10, children: [
            SizedBox(width: 220, child: StatCard(label: 'Vues des annonces', value: a.totalViews, icon: Icons.visibility_outlined)),
            SizedBox(
              width: 220,
              child: StatCard(label: 'Ajouts en favoris', value: a.totalFavorites, icon: Icons.favorite_border, color: AppColors.accent),
            ),
            for (final e in a.averagePrice.entries)
              SizedBox(
                width: 220,
                child: AdminCard(
                  child: ListTile(
                    leading: const Icon(Icons.payments_outlined, color: AppColors.primary),
                    title: Text(fmtPrice(e.value), style: const TextStyle(fontWeight: FontWeight.w800)),
                    subtitle: Text('Prix moyen · ${e.key == 'rent' ? 'location' : 'vente'}'),
                  ),
                ),
              ),
          ]),
          const AdminSectionTitle('Croissance (6 derniers mois)'),
          AdminCard(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(children: [
                _GrowthRow(label: 'Nouvelles annonces', data: a.listingGrowth, color: AppColors.primary),
                const SizedBox(height: 14),
                _GrowthRow(label: 'Nouveaux utilisateurs', data: a.userGrowth, color: AppColors.accent),
              ]),
            ),
          ),
          const AdminSectionTitle('Annonces publiées par gouvernorat'),
          _Bars(entries: a.byGovernorate.take(12).toList()),
          const AdminSectionTitle('Annonces publiées par type'),
          _Bars(entries: [for (final e in a.byType) MapEntry(types[e.key] ?? e.key, e.value)]),
          const AdminSectionTitle('Annonces par statut'),
          _Bars(entries: [
            for (final e in a.byStatus) MapEntry(_statusLabel(e.key), e.value),
          ]),
          const SizedBox(height: 24),
        ]),
      ),
    );
  }

  static String _statusLabel(String wire) => switch (wire) {
        'pending_review' => 'En attente',
        'published' => 'Publiée',
        'rejected' => 'Refusée',
        'suspended' => 'Suspendue',
        'removed' => 'Retirée',
        'expired' => 'Expirée',
        'draft' => 'Brouillon',
        _ => wire,
      };
}

/// Horizontal bars, no chart package needed.
class _Bars extends StatelessWidget {
  const _Bars({required this.entries});
  final List<MapEntry<String, int>> entries;

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) {
      return const AdminCard(child: ListTile(title: Text('Pas encore de données.')));
    }
    final max = entries.map((e) => e.value).reduce((a, b) => a > b ? a : b);
    return AdminCard(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(children: [
          for (final e in entries)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Row(children: [
                SizedBox(width: 130, child: Text(e.key, overflow: TextOverflow.ellipsis)),
                Expanded(
                  child: LinearProgressIndicator(
                    value: max == 0 ? 0 : e.value / max,
                    minHeight: 10,
                    borderRadius: BorderRadius.circular(6),
                    color: AppColors.navy,
                    backgroundColor: AppColors.line,
                  ),
                ),
                SizedBox(
                  width: 44,
                  child: Text('${e.value}', textAlign: TextAlign.right, style: const TextStyle(fontWeight: FontWeight.w700)),
                ),
              ]),
            ),
        ]),
      ),
    );
  }
}

class _GrowthRow extends StatelessWidget {
  const _GrowthRow({required this.label, required this.data, required this.color});
  final String label;
  final List<MapEntry<String, int>> data;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final max = data.isEmpty ? 0 : data.map((e) => e.value).reduce((a, b) => a > b ? a : b);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
      const SizedBox(height: 8),
      SizedBox(
        height: 120,
        child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          for (final e in data)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
                  Text('${e.value}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 2),
                  Container(
                    height: max == 0 ? 2 : 2 + 78 * e.value / max,
                    decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(4)),
                  ),
                  const SizedBox(height: 4),
                  Text(_monthLabel(e.key), style: const TextStyle(fontSize: 10.5, color: AppColors.muted)),
                ]),
              ),
            ),
        ]),
      ),
    ]);
  }
}
