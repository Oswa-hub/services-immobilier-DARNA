import '../../../core/constants/tunisia_governorates.dart';
import '../../properties/domain/entities/amenity.dart';
import '../../properties/domain/entities/property.dart';

/// Module 16 — content managed by the admin without changing Flutter code.
///
/// One Firestore document per list: `catalog/{key.docId}` =
/// `{ items: [{id, label, active, order}], updatedAt, updatedBy }`.
///
/// "Built-in" lists (property types, amenities) are tied to code: their ids
/// are enum names stored on listings and used by search. The admin may rename
/// them (label shown to users), hide them, or reorder them, but not add or
/// delete ids. The other lists are free: add, rename, hide, reorder, delete.
enum CatalogKey {
  propertyTypes('property_types', 'Types de biens', builtIn: true),
  amenities('amenities', 'Équipements', builtIn: true),
  cities('cities', 'Villes'),
  areas('areas', 'Quartiers'),
  tags('tags', 'Étiquettes'),
  verificationCategories('verification_categories', 'Catégories de vérification'),
  reportReasons('report_reasons', 'Motifs de signalement');

  const CatalogKey(this.docId, this.label, {this.builtIn = false});

  final String docId;
  final String label;
  final bool builtIn;

  /// Content used while the document does not exist yet.
  List<CatalogItem> get defaults => switch (this) {
        CatalogKey.propertyTypes => [
            for (final (i, t) in PropertyType.values.indexed)
              CatalogItem(id: t.name, label: _propertyTypeLabels[t] ?? t.name, order: i),
          ],
        CatalogKey.amenities => [
            for (final (i, a) in Amenity.values.indexed) CatalogItem(id: a.id, label: a.label, order: i),
          ],
        CatalogKey.cities => [
            for (final (i, g) in tunisiaGovernorates.indexed) CatalogItem(id: slugify(g), label: g, order: i),
          ],
        CatalogKey.areas || CatalogKey.tags => const [],
        CatalogKey.verificationCategories => _list(const ['Identité', 'Propriétaire', 'Agent / agence', 'Bien immobilier']),
        CatalogKey.reportReasons => _list(const [
            'Annonce frauduleuse',
            'Bien déjà vendu ou loué',
            'Prix ou informations trompeurs',
            'Photos inappropriées',
            'Doublon',
            'Comportement abusif',
            'Autre',
          ]),
      };

  static List<CatalogItem> _list(List<String> labels) => [
        for (final (i, l) in labels.indexed) CatalogItem(id: slugify(l), label: l, order: i),
      ];
}

const _propertyTypeLabels = {
  PropertyType.apartment: 'Appartement',
  PropertyType.villa: 'Villa',
  PropertyType.house: 'Maison',
  PropertyType.duplex: 'Duplex',
  PropertyType.triplex: 'Triplex',
  PropertyType.land: 'Terrain',
  PropertyType.office: 'Bureau',
  PropertyType.commercial: 'Local commercial',
  PropertyType.industrial: 'Local industriel',
  PropertyType.other: 'Autre',
};

class CatalogItem {
  const CatalogItem({required this.id, required this.label, this.active = true, this.order = 0});

  final String id;
  final String label;
  final bool active;
  final int order;

  static CatalogItem? tryFromMap(Object? raw) {
    if (raw is! Map) return null;
    final id = raw['id'];
    final label = raw['label'];
    if (id is! String || id.isEmpty || label is! String || label.trim().isEmpty) return null;
    final order = raw['order'];
    return CatalogItem(
      id: id,
      label: label.trim(),
      active: raw['active'] is bool ? raw['active'] as bool : true,
      order: order is num ? order.toInt() : 0,
    );
  }

  Map<String, dynamic> toMap() => {'id': id, 'label': label, 'active': active, 'order': order};

  CatalogItem copyWith({String? label, bool? active, int? order}) =>
      CatalogItem(id: id, label: label ?? this.label, active: active ?? this.active, order: order ?? this.order);

  @override
  bool operator ==(Object other) =>
      other is CatalogItem && other.id == id && other.label == label && other.active == active && other.order == order;

  @override
  int get hashCode => Object.hash(id, label, active, order);
}

/// "Vue mer & piscine" -> "vue_mer_piscine". Stable ids for free lists.
String slugify(String input) {
  const accents = {
    'à': 'a', 'â': 'a', 'ä': 'a', 'á': 'a', 'ç': 'c', 'é': 'e', 'è': 'e', 'ê': 'e', 'ë': 'e',
    'î': 'i', 'ï': 'i', 'í': 'i', 'ô': 'o', 'ö': 'o', 'ó': 'o', 'ù': 'u', 'û': 'u', 'ü': 'u', 'ú': 'u',
    'ÿ': 'y', 'œ': 'oe', 'æ': 'ae',
  };
  final b = StringBuffer();
  for (final ch in input.toLowerCase().split('')) {
    b.write(accents[ch] ?? ch);
  }
  return b
      .toString()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
      .replaceAll(RegExp(r'^_+|_+$'), '');
}

/// Pure, immutable editing of one list. Every operation returns a NEW list
/// with `order` renumbered 0..n-1, or throws [CatalogEditException].
class CatalogEditor {
  CatalogEditor._();

  static const maxItems = 200;
  static const maxLabelLength = 60;

  /// Items sorted by `order`, then label (stable display).
  static List<CatalogItem> sorted(List<CatalogItem> items) =>
      [...items]..sort((a, b) => a.order != b.order ? a.order.compareTo(b.order) : a.label.compareTo(b.label));

  static List<CatalogItem> _renumber(List<CatalogItem> items) => [
        for (final (i, it) in items.indexed) it.order == i ? it : it.copyWith(order: i),
      ];

  static String _cleanLabel(String label) {
    final l = label.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (l.isEmpty) throw const CatalogEditException('Le libellé est obligatoire.');
    if (l.length > maxLabelLength) throw const CatalogEditException('Libellé trop long ($maxLabelLength caractères max).');
    return l;
  }

  static List<CatalogItem> add(CatalogKey key, List<CatalogItem> items, String label) {
    if (key.builtIn) {
      throw const CatalogEditException('Cette liste est liée au code : on peut renommer ou masquer, pas ajouter.');
    }
    if (items.length >= maxItems) throw const CatalogEditException('Liste pleine ($maxItems éléments max).');
    final clean = _cleanLabel(label);
    final id = slugify(clean);
    if (id.isEmpty) throw const CatalogEditException('Le libellé doit contenir des lettres ou des chiffres.');
    if (items.any((i) => i.id == id || i.label.toLowerCase() == clean.toLowerCase())) {
      throw const CatalogEditException('Cet élément existe déjà.');
    }
    final list = sorted(items);
    return _renumber([...list, CatalogItem(id: id, label: clean, order: list.length)]);
  }

  static List<CatalogItem> rename(List<CatalogItem> items, String id, String label) {
    final clean = _cleanLabel(label);
    if (items.any((i) => i.id != id && i.label.toLowerCase() == clean.toLowerCase())) {
      throw const CatalogEditException('Un autre élément porte déjà ce libellé.');
    }
    return _renumber([for (final i in sorted(items)) i.id == id ? i.copyWith(label: clean) : i]);
  }

  static List<CatalogItem> toggle(List<CatalogItem> items, String id) =>
      _renumber([for (final i in sorted(items)) i.id == id ? i.copyWith(active: !i.active) : i]);

  /// Moves item [id] by [delta] positions (-1 up, +1 down), clamped.
  static List<CatalogItem> move(List<CatalogItem> items, String id, int delta) {
    final list = sorted(items);
    final from = list.indexWhere((i) => i.id == id);
    if (from < 0) return _renumber(list);
    final to = (from + delta).clamp(0, list.length - 1);
    final item = list.removeAt(from);
    list.insert(to, item);
    return _renumber(list);
  }

  static List<CatalogItem> remove(CatalogKey key, List<CatalogItem> items, String id) {
    if (key.builtIn) {
      throw const CatalogEditException('Cette liste est liée au code : masquez l’élément au lieu de le supprimer.');
    }
    return _renumber([for (final i in sorted(items)) if (i.id != id) i]);
  }

  /// Restores the built-in ids a stored list may be missing (new app version),
  /// and drops unknown ids from built-in lists. Free lists are returned as is.
  static List<CatalogItem> reconcile(CatalogKey key, List<CatalogItem> stored) {
    if (!key.builtIn) return sorted(stored);
    final defaults = key.defaults;
    final known = {for (final d in defaults) d.id};
    final kept = [for (final s in sorted(stored)) if (known.contains(s.id)) s];
    final keptIds = {for (final k in kept) k.id};
    return _renumber([...kept, for (final d in defaults) if (!keptIds.contains(d.id)) d]);
  }
}

class CatalogEditException implements Exception {
  const CatalogEditException(this.message);
  final String message;

  @override
  String toString() => message;
}
