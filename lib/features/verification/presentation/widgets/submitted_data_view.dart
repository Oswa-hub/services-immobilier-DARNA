import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../domain/entities/verification_enums.dart';

/// Read-only view of `submittedData` with human labels. Unknown keys are not
/// shown, so a malformed record can never render arbitrary content.
class SubmittedDataView extends StatelessWidget {
  const SubmittedDataView({super.key, required this.type, required this.data});

  final VerificationTargetType type;
  final Map<String, dynamic> data;

  static const _labels = <String, String>{
    'fullName': 'Nom complet',
    'phone': 'Numéro de téléphone',
    'propertyReference': 'Bien concerné',
    'agencyName': 'Nom de l\'agence',
    'agencyAddress': 'Adresse de l\'agence',
    'propertyTitle': 'Annonce',
    'city': 'Ville',
    'locationProvided': 'Localisation fournie',
    'listingInformationProvided': 'Informations de l\'annonce fournies',
    'photoCount': 'Photos',
    'emailConfirmed': 'E-mail confirmé',
    // Honest wording: no phone code is sent yet (spec §2.2).
    'phoneConfirmed': 'Téléphone confirmé par code',
  };

  static String _value(Object? v) => switch (v) {
        true => 'Oui',
        false => 'Non',
        null => '-',
        _ => v.toString(),
      };

  @override
  Widget build(BuildContext context) {
    final rows = [
      for (final e in _labels.entries)
        if (data.containsKey(e.key)) (e.value, _value(data[e.key])),
    ];
    if (rows.isEmpty) return const Text('Aucune information.', style: TextStyle(color: AppColors.muted));
    return Column(children: [
      for (final r in rows)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            SizedBox(width: 170, child: Text(r.$1, style: const TextStyle(color: AppColors.muted, fontSize: 13))),
            Expanded(child: Text(r.$2, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13))),
          ]),
        ),
    ]);
  }
}
