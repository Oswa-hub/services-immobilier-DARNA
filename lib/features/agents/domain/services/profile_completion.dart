import '../entities/agent_profile.dart';

/// "Profile completion indicator" of the dashboard (spec §5.2).
/// Weighted by what helps a visitor trust the profile.
class ProfileCompletion {
  const ProfileCompletion(this.percent, this.missing);

  /// 0..100
  final int percent;

  /// Human labels of the optional items still empty, most valuable first.
  final List<String> missing;

  bool get isComplete => percent >= 100;

  static ProfileCompletion of(AgentProfile p) {
    // Required fields are always filled once the profile exists: 60 points.
    var score = 60;
    final missing = <String>[];

    void item(bool done, int points, String label) {
      if (done) {
        score += points;
      } else {
        missing.add(label);
      }
    }

    bool has(String? s) => s != null && s.trim().isNotEmpty;

    item(has(p.profileImageUrl), 15, p.isAgency ? 'Ajoutez votre logo' : 'Ajoutez une photo de profil');
    item(p.serviceAreas.isNotEmpty, 7, 'Ajoutez vos zones desservies');
    item(has(p.address), 5, 'Ajoutez l\'adresse de votre bureau');
    item(p.languages.isNotEmpty, 4, 'Ajoutez les langues parlées');
    item(has(p.website), 4, 'Ajoutez votre site web');
    item(p.yearsOfExperience != null, 5, 'Ajoutez vos années d\'expérience');

    return ProfileCompletion(score.clamp(0, 100), missing);
  }
}
