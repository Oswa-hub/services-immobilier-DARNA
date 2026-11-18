import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/admin_failure.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../auth/providers/auth_provider.dart';
import '../../domain/catalog.dart';
import '../providers/catalog_providers.dart';

/// Module 16 — `/admin/content`: one tab per managed list.
class AdminContentPage extends StatelessWidget {
  const AdminContentPage({super.key});

  @override
  Widget build(BuildContext context) => DefaultTabController(
        length: CatalogKey.values.length,
        child: Column(children: [
          Material(
            color: Colors.white,
            child: TabBar(
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              tabs: [for (final k in CatalogKey.values) Tab(text: k.label)],
            ),
          ),
          Expanded(
            child: TabBarView(children: [
              for (final k in CatalogKey.values) CatalogEditorView(key: ValueKey(k), catalogKey: k),
            ]),
          ),
        ]),
      );
}

/// Edits a local copy; nothing is written until "Enregistrer".
class CatalogEditorView extends ConsumerStatefulWidget {
  const CatalogEditorView({super.key, required this.catalogKey});

  final CatalogKey catalogKey;

  @override
  ConsumerState<CatalogEditorView> createState() => _CatalogEditorViewState();
}

class _CatalogEditorViewState extends ConsumerState<CatalogEditorView> {
  List<CatalogItem>? _draft;
  List<CatalogItem>? _base;
  final _add = TextEditingController();
  bool _saving = false;

  CatalogKey get _key => widget.catalogKey;
  bool get _dirty => _draft != null && _base != null && !_sameList(_draft!, _base!);

  static bool _sameList(List<CatalogItem> a, List<CatalogItem> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  @override
  void dispose() {
    _add.dispose();
    super.dispose();
  }

  void _apply(List<CatalogItem> Function(List<CatalogItem>) edit) {
    try {
      setState(() => _draft = edit(_draft!));
    } on CatalogEditException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<void> _rename(CatalogItem item) async {
    final controller = TextEditingController(text: item.label);
    final label = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Renommer'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: CatalogEditor.maxLabelLength,
          decoration: const InputDecoration(labelText: 'Libellé'),
          onSubmitted: (v) => Navigator.of(ctx).pop(v),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Annuler')),
          FilledButton(onPressed: () => Navigator.of(ctx).pop(controller.text), child: const Text('OK')),
        ],
      ),
    );
    // Not disposed: the dialog may still be animating out with it.
    if (label != null && mounted) _apply((l) => CatalogEditor.rename(l, item.id, label));
  }

  Future<void> _save() async {
    final adminId = ref.read(currentUserProvider)?.id;
    if (adminId == null || _draft == null) return;
    setState(() => _saving = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(catalogRepositoryProvider).save(_key, _draft!, adminId: adminId);
      setState(() => _base = _draft);
      messenger.showSnackBar(SnackBar(content: Text('« ${_key.label} » enregistré.')));
    } on AdminFailure catch (f) {
      messenger.showSnackBar(SnackBar(content: Text(f.message), backgroundColor: AppColors.error));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(catalogStreamProvider(_key));

    // Take the remote list as the base when nothing is being edited.
    final remote = async.value;
    if (remote != null && !_dirty && !_saving && (_base == null || !_sameList(_base!, remote))) {
      _base = remote;
      _draft = remote;
    }

    if (_draft == null) {
      return async.when(
        data: (_) => const SizedBox.shrink(),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text(e is AdminFailure ? e.message : 'Chargement impossible.')),
      );
    }

    final items = CatalogEditor.sorted(_draft!);
    return Column(children: [
      Container(
        width: double.infinity,
        color: AppColors.chip,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Text(
          _key.builtIn
              ? 'Liste liée au code : vous pouvez renommer, masquer et réordonner les éléments.'
              : 'Ajoutez, renommez, masquez, réordonnez ou supprimez des éléments.',
          style: const TextStyle(color: AppColors.navy, fontSize: 13),
        ),
      ),
      if (!_key.builtIn)
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Row(children: [
            Expanded(
              child: TextField(
                controller: _add,
                maxLength: CatalogEditor.maxLabelLength,
                decoration: const InputDecoration(labelText: 'Nouvel élément', counterText: ''),
                onSubmitted: (_) => _addItem(),
              ),
            ),
            const SizedBox(width: 8),
            FilledButton.tonalIcon(onPressed: _addItem, icon: const Icon(Icons.add), label: const Text('Ajouter')),
          ]),
        ),
      Expanded(
        child: items.isEmpty
            ? const Center(child: Text('Aucun élément.', style: TextStyle(color: AppColors.muted)))
            : ListView.separated(
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: items.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (_, i) {
                  final it = items[i];
                  return ListTile(
                    title: Text(
                      it.label,
                      style: TextStyle(color: it.active ? AppColors.text : AppColors.muted),
                    ),
                    subtitle: Text(it.active ? it.id : '${it.id} · masqué',
                        style: const TextStyle(fontSize: 12, color: AppColors.muted)),
                    onTap: () => _rename(it),
                    trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                      IconButton(
                        tooltip: 'Monter',
                        onPressed: i == 0 ? null : () => _apply((l) => CatalogEditor.move(l, it.id, -1)),
                        icon: const Icon(Icons.arrow_upward_rounded),
                      ),
                      IconButton(
                        tooltip: 'Descendre',
                        onPressed: i == items.length - 1 ? null : () => _apply((l) => CatalogEditor.move(l, it.id, 1)),
                        icon: const Icon(Icons.arrow_downward_rounded),
                      ),
                      Switch(
                        value: it.active,
                        onChanged: (_) => _apply((l) => CatalogEditor.toggle(l, it.id)),
                      ),
                      if (!_key.builtIn)
                        IconButton(
                          tooltip: 'Supprimer',
                          onPressed: () => _apply((l) => CatalogEditor.remove(_key, l, it.id)),
                          icon: const Icon(Icons.delete_outline_rounded, color: AppColors.error),
                        ),
                    ]),
                  );
                },
              ),
      ),
      SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(children: [
            if (_dirty)
              TextButton(
                onPressed: _saving ? null : () => setState(() => _draft = _base),
                child: const Text('Annuler les modifications'),
              ),
            const Spacer(),
            FilledButton.icon(
              onPressed: _dirty && !_saving ? _save : null,
              icon: const Icon(Icons.save_outlined),
              label: const Text('Enregistrer'),
            ),
          ]),
        ),
      ),
    ]);
  }

  void _addItem() {
    try {
      final next = CatalogEditor.add(_key, _draft!, _add.text);
      setState(() => _draft = next);
      _add.clear(); // keep the text when it was refused, so it can be fixed
    } on CatalogEditException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }
}
