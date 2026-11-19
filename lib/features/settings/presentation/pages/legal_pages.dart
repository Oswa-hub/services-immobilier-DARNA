import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../providers/platform_settings_providers.dart';

enum LegalDocument {
  terms('Conditions d’utilisation'),
  privacy('Politique de confidentialité');

  const LegalDocument(this.title);
  final String title;
}

/// Module 17 — `/legal/terms` and `/legal/privacy`, open to everyone. The text
/// is edited by the admin in `/admin/settings`.
class LegalPage extends ConsumerWidget {
  const LegalPage({super.key, required this.document});

  final LegalDocument document;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(platformSettingsProvider);
    final text = document == LegalDocument.terms ? s.termsText : s.privacyText;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: Text(document.title)),
      body: text.isEmpty
          ? const _Empty(
              icon: Icons.description_outlined,
              message: 'Ce document n’est pas encore disponible.',
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: SelectableText(text, style: const TextStyle(fontSize: 15, height: 1.5, color: AppColors.text)),
            ),
    );
  }
}

/// Module 17 — `/contact`.
class ContactPage extends ConsumerWidget {
  const ContactPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(platformSettingsProvider);
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Nous contacter')),
      body: !s.hasContact
          ? const _Empty(icon: Icons.support_agent_outlined, message: 'Les coordonnées seront bientôt disponibles.')
          : ListView(padding: const EdgeInsets.all(16), children: [
              if (s.contactEmail.isNotEmpty)
                _Line(icon: Icons.email_outlined, label: 'E-mail', value: s.contactEmail),
              if (s.contactPhone.isNotEmpty)
                _Line(icon: Icons.phone_outlined, label: 'Téléphone', value: s.contactPhone),
              if (s.contactAddress.isNotEmpty)
                _Line(icon: Icons.place_outlined, label: 'Adresse', value: s.contactAddress),
            ]),
    );
  }
}

class _Line extends StatelessWidget {
  const _Line({required this.icon, required this.label, required this.value});
  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Card(
        elevation: 0,
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: AppColors.line),
        ),
        child: ListTile(
          leading: Icon(icon, color: AppColors.primary),
          title: Text(label, style: const TextStyle(color: AppColors.muted, fontSize: 13)),
          subtitle: SelectableText(value, style: const TextStyle(color: AppColors.text, fontSize: 15)),
        ),
      );
}

class _Empty extends StatelessWidget {
  const _Empty({required this.icon, required this.message});
  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 52, color: AppColors.muted),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.muted)),
          ]),
        ),
      );
}
