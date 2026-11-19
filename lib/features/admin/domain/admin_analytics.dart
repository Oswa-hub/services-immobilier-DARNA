import '../../properties/domain/entities/property.dart';
import 'admin_models.dart';

/// Pure analytics over a sample of documents (the most recent ones).
AdminAnalytics computeAnalytics({
  required List<Property> properties,
  required List<AdminUser> users,
  required DateTime now,
  int months = 6,
}) {
  final published = [for (final p in properties) if (p.status == PropertyStatus.published) p];

  List<MapEntry<String, int>> countBy<T>(Iterable<T> items, String Function(T) key) {
    final m = <String, int>{};
    for (final i in items) {
      final k = key(i);
      m[k] = (m[k] ?? 0) + 1;
    }
    return m.entries.toList()..sort((a, b) => b.value != a.value ? b.value.compareTo(a.value) : a.key.compareTo(b.key));
  }

  final averages = <String, double>{};
  for (final tx in TransactionType.values) {
    final prices = [for (final p in published) if (p.transactionType == tx) p.price.toDouble()];
    if (prices.isNotEmpty) averages[tx.name] = prices.reduce((a, b) => a + b) / prices.length;
  }

  // Month buckets, oldest first.
  final keys = <String>[
    for (var i = months - 1; i >= 0; i--) monthKey(DateTime(now.year, now.month - i)),
  ];
  List<MapEntry<String, int>> growth(Iterable<DateTime?> dates) {
    final m = {for (final k in keys) k: 0};
    for (final d in dates) {
      if (d == null) continue;
      final k = monthKey(d);
      if (m.containsKey(k)) m[k] = m[k]! + 1;
    }
    return [for (final k in keys) MapEntry(k, m[k]!)];
  }

  return AdminAnalytics(
    sampledProperties: properties.length,
    sampledUsers: users.length,
    byGovernorate: countBy(published, (p) => p.governorate),
    byType: countBy(published, (p) => p.propertyType.name),
    byStatus: countBy(properties, (p) => p.status.wire),
    averagePrice: averages,
    listingGrowth: growth(properties.map((p) => p.createdAt)),
    userGrowth: growth(users.map((u) => u.createdAt)),
    totalViews: properties.fold(0, (s, p) => s + p.views),
    totalFavorites: properties.fold(0, (s, p) => s + p.favoritesCount),
  );
}

String monthKey(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}';
