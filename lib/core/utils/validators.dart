/// Pure form validators (unit-tested). Each returns an error message or null.
class Validators {
  Validators._();

  static const minPasswordLength = 8;

  static final _email = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]{2,}$');
  // Tunisian numbers: optional +216 / 00216 / 216 prefix + 8 digits starting 2,3,4,5,7 or 9.
  static final _tnPhone = RegExp(r'^(?:\+216|00216|216)?([2-579]\d{7})$');

  static String _cleanPhone(String v) => v.replaceAll(RegExp(r'[\s\-().]'), '');

  static String? fullName(String? v) {
    final value = v?.trim() ?? '';
    if (value.isEmpty) return 'Le nom complet est obligatoire';
    if (value.length < 3) return 'Nom complet trop court';
    return null;
  }

  static String? email(String? v) {
    final value = v?.trim() ?? '';
    if (value.isEmpty) return 'L\'e-mail est obligatoire';
    if (!_email.hasMatch(value)) return 'Saisissez une adresse e-mail valide';
    return null;
  }

  static String? phone(String? v) {
    final value = v?.trim() ?? '';
    if (value.isEmpty) return 'Le numéro de téléphone est obligatoire';
    if (!_tnPhone.hasMatch(_cleanPhone(value))) return 'Saisissez un numéro valide';
    return null;
  }

  /// Returns the phone as `+216XXXXXXXX` (or the trimmed input if it is invalid).
  static String normalizePhone(String v) {
    final m = _tnPhone.firstMatch(_cleanPhone(v.trim()));
    return m == null ? v.trim() : '+216${m.group(1)}';
  }

  static String? password(String? v) {
    final value = v ?? '';
    if (value.isEmpty) return 'Le mot de passe est obligatoire';
    final r = passwordRules(value);
    if (!r.minLength) return 'Au moins $minPasswordLength caractères';
    if (!r.uppercase) return 'Ajoutez une lettre majuscule';
    if (!r.number) return 'Ajoutez un chiffre';
    return null;
  }

  /// Login only checks presence: the server decides whether credentials are valid.
  static String? loginPassword(String? v) =>
      (v == null || v.isEmpty) ? 'Le mot de passe est obligatoire' : null;

  static String? confirmPassword(String? v, String original) {
    if (v == null || v.isEmpty) return 'Confirmez votre mot de passe';
    if (v != original) return 'Les mots de passe ne correspondent pas';
    return null;
  }

  static ({bool minLength, bool uppercase, bool number}) passwordRules(String v) => (
        minLength: v.length >= minPasswordLength,
        uppercase: RegExp(r'[A-Z]').hasMatch(v),
        number: RegExp(r'\d').hasMatch(v),
      );
}
