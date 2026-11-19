import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/admin_failure.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../auth/providers/auth_provider.dart';
import '../../domain/platform_settings.dart';
import '../providers/platform_settings_providers.dart';

/// Module 17 — `/admin/settings`: limits, moderation, currencies, legal texts
/// and contact, saved to `settings/platform` (+ an audit log entry).
class AdminSettingsPage extends ConsumerStatefulWidget {
  const AdminSettingsPage({super.key});

  @override
  ConsumerState<AdminSettingsPage> createState() => _AdminSettingsPageState();
}

class _AdminSettingsPageState extends ConsumerState<AdminSettingsPage> {
  PlatformSettings? _draft;
  final _terms = TextEditingController();
  final _privacy = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _address = TextEditingController();
  Map<String, String> _errors = const {};
  bool _saving = false;

  @override
  void dispose() {
    for (final c in [_terms, _privacy, _email, _phone, _address]) {
      c.dispose();
    }
    super.dispose();
  }

  void _load(PlatformSettings s) {
    _draft = s;
    _terms.text = s.termsText;
    _privacy.text = s.privacyText;
    _email.text = s.contactEmail;
    _phone.text = s.contactPhone;
    _address.text = s.contactAddress;
  }

  PlatformSettings _collect() => _draft!.copyWith(
        termsText: _terms.text.trim(),
        privacyText: _privacy.text.trim(),
        contactEmail: _email.text.trim(),
        contactPhone: _phone.text.trim(),
        contactAddress: _address.text.trim(),
      );

  Future<void> _save() async {
    final next = _collect();
    final errors = next.validate();
    setState(() => _errors = errors);
    if (errors.isNotEmpty) return;
    final adminId = ref.read(currentUserProvider)?.id;
    if (adminId == null) return;

    setState(() => _saving = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(platformSettingsRepositoryProvider).save(next, adminId: adminId);
      messenger.showSnackBar(const SnackBar(content: Text('Paramètres enregistrés.')));
    } on AdminFailure catch (f) {
      messenger.showSnackBar(SnackBar(content: Text(f.message), backgroundColor: AppColors.error));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(platformSettingsStreamProvider);

    if (_draft == null) {
      return async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(e is AdminFailure ? e.message : 'Impossible de charger les paramètres.'),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: () => ref.invalidate(platformSettingsStreamProvider),
              child: const Text('Réessayer'),
            ),
          ]),
        ),
        data: (s) {
          // First data: fill the form once (later remote changes do not erase typing).
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && _draft == null) setState(() => _load(s));
          });
          return const Center(child: CircularProgressIndicator());
        },
      );
    }

    final d = _draft!;
    final updatedAt = async.value?.updatedAt;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760),
        child: ListView(padding: const EdgeInsets.all(16), children: [
          if (updatedAt != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                'Dernière modification : ${_fmt(updatedAt)}',
                style: const TextStyle(color: AppColors.muted, fontSize: 12.5),
              ),
            ),
          _Section(title: 'Annonces', children: [
            _Stepper(
              label: 'Nombre maximum de photos',
              value: d.maxImages,
              min: PlatformSettings.minImages,
              max: PlatformSettings.hardMaxImages,
              error: _errors['maxImages'],
              onChanged: (v) => setState(() => _draft = d.copyWith(maxImages: v)),
            ),
            _Stepper(
              label: 'Taille maximum par photo (Mo)',
              value: d.maxImageSizeMb,
              min: 1,
              max: PlatformSettings.hardMaxImageSizeMb,
              error: _errors['maxImageSizeMb'],
              onChanged: (v) => setState(() => _draft = d.copyWith(maxImageSizeMb: v)),
            ),
            _Stepper(
              label: 'Durée de publication (jours)',
              value: d.listingExpirationDays,
              min: PlatformSettings.minExpirationDays,
              max: PlatformSettings.maxExpirationDays,
              step: 7,
              error: _errors['listingExpirationDays'],
              onChanged: (v) => setState(() => _draft = d.copyWith(listingExpirationDays: v)),
            ),
          ]),
          _Section(title: 'Modération et notifications', children: [
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Validation des annonces par un administrateur'),
              subtitle: const Text('Les nouvelles annonces restent « en attente » jusqu’à approbation.'),
              value: d.requireListingReview,
              onChanged: (v) => setState(() => _draft = d.copyWith(requireListingReview: v)),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Annonces de la plateforme'),
              subtitle: const Text('Autorise l’envoi de notifications à tous les utilisateurs.'),
              value: d.announcementsEnabled,
              onChanged: (v) => setState(() => _draft = d.copyWith(announcementsEnabled: v)),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Notifications envoyées par Cloud Functions'),
              subtitle: const Text(
                'À activer seulement après le déploiement des Functions (plan Blaze). '
                'Désactivé : l’application admin envoie elle-même les notifications de modération.',
              ),
              value: d.serverNotifications,
              onChanged: (v) => setState(() => _draft = d.copyWith(serverNotifications: v)),
            ),
          ]),
          _Section(title: 'Devises acceptées', children: [
            Wrap(spacing: 8, children: [
              for (final c in PlatformSettings.allCurrencies)
                FilterChip(
                  label: Text(c),
                  selected: d.supportedCurrencies.contains(c),
                  onSelected: (on) {
                    final next = [...d.supportedCurrencies]..remove(c);
                    if (on) next.add(c);
                    setState(() => _draft = d.copyWith(supportedCurrencies: next));
                  },
                ),
            ]),
            if (_errors['supportedCurrencies'] != null) _ErrorText(_errors['supportedCurrencies']!),
          ]),
          _Section(title: 'Contact', children: [
            _Field(controller: _email, label: 'E-mail', error: _errors['contactEmail'], keyboard: TextInputType.emailAddress),
            _Field(controller: _phone, label: 'Téléphone', error: _errors['contactPhone'], keyboard: TextInputType.phone),
            _Field(controller: _address, label: 'Adresse', error: _errors['contactAddress']),
          ]),
          _Section(title: 'Textes légaux', children: [
            _Field(controller: _terms, label: 'Conditions d’utilisation', error: _errors['termsText'], lines: 8),
            _Field(controller: _privacy, label: 'Politique de confidentialité', error: _errors['privacyText'], lines: 8),
          ]),
          const SizedBox(height: 8),
          FilledButton.icon(
            onPressed: _saving ? null : _save,
            icon: _saving
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.save_outlined),
            label: const Text('Enregistrer'),
          ),
          const SizedBox(height: 24),
        ]),
      ),
    );
  }

  static String _fmt(DateTime d) {
    String two(int v) => v.toString().padLeft(2, '0');
    return '${two(d.day)}/${two(d.month)}/${d.year} ${two(d.hour)}:${two(d.minute)}';
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.children});
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Card(
        elevation: 0,
        color: Colors.white,
        margin: const EdgeInsets.only(bottom: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: AppColors.line),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: AppColors.navy)),
            const SizedBox(height: 8),
            ...children,
          ]),
        ),
      );
}

class _Stepper extends StatelessWidget {
  const _Stepper({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
    this.step = 1,
    this.error,
  });

  final String label;
  final int value;
  final int min;
  final int max;
  final int step;
  final String? error;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text(label)),
            IconButton(
              tooltip: 'Diminuer',
              onPressed: value <= min ? null : () => onChanged((value - step).clamp(min, max)),
              icon: const Icon(Icons.remove_circle_outline),
            ),
            SizedBox(
              width: 44,
              child: Text('$value', textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w800)),
            ),
            IconButton(
              tooltip: 'Augmenter',
              onPressed: value >= max ? null : () => onChanged((value + step).clamp(min, max)),
              icon: const Icon(Icons.add_circle_outline),
            ),
          ]),
          if (error != null) _ErrorText(error!),
        ]),
      );
}

class _Field extends StatelessWidget {
  const _Field({required this.controller, required this.label, this.error, this.lines = 1, this.keyboard});

  final TextEditingController controller;
  final String label;
  final String? error;
  final int lines;
  final TextInputType? keyboard;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: TextField(
          controller: controller,
          minLines: lines,
          maxLines: lines == 1 ? 1 : 20,
          keyboardType: lines == 1 ? keyboard : TextInputType.multiline,
          decoration: InputDecoration(labelText: label, errorText: error, border: const OutlineInputBorder()),
        ),
      );
}

class _ErrorText extends StatelessWidget {
  const _ErrorText(this.text);
  final String text;

  @override
  Widget build(BuildContext context) =>
      Padding(padding: const EdgeInsets.only(top: 4), child: Text(text, style: const TextStyle(color: AppColors.error)));
}
