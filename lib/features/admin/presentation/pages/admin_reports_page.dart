import 'package:flutter/material.dart';

import '../widgets/admin_widgets.dart';

/// Module 15 — `/admin/reports` (spec §41). The report queue (assign,
/// investigate, resolve, reject) arrives with Module 14 (Reports & Safety),
/// which creates the `reports` collection. The reasons users will choose from
/// are already editable in Contenu > Motifs de signalement (Module 16).
class AdminReportsPage extends StatelessWidget {
  const AdminReportsPage({super.key});

  @override
  Widget build(BuildContext context) => const AdminMessage(
        icon: Icons.flag_outlined,
        text: 'La gestion des signalements sera disponible avec le Module 14 (Signalements & sécurité).\n'
            'Les motifs proposés aux utilisateurs se règlent déjà dans « Contenu ».',
      );
}
