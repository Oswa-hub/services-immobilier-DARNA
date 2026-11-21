/// Application-level authentication errors (spec §38).
///
/// The UI never sees Firebase exceptions: the data layer maps them to this type.
enum AuthFailureType {
  invalidCredentials,
  emailAlreadyUsed,
  weakPassword,
  invalidEmail,
  userNotFound,
  tooManyRequests,
  networkError,
  verificationRequired,
  accountSuspended,
  accountBanned,
  googleSignInFailed,
  googleCancelled,
  invalidResetCode,
  unknown,
}

class AuthFailure implements Exception {
  const AuthFailure(this.type);

  final AuthFailureType type;

  /// User-friendly message. Never contains raw backend error text.
  String get message => switch (type) {
        AuthFailureType.invalidCredentials => 'E-mail ou mot de passe incorrect.',
        AuthFailureType.emailAlreadyUsed => 'Un compte existe déjà avec cet e-mail.',
        AuthFailureType.weakPassword => 'Mot de passe trop faible. Choisissez-en un plus solide.',
        AuthFailureType.invalidEmail => 'Saisissez une adresse e-mail valide.',
        // Same text as invalidCredentials on purpose: do not reveal which emails exist.
        AuthFailureType.userNotFound => 'E-mail ou mot de passe incorrect.',
        AuthFailureType.tooManyRequests => 'Trop de tentatives. Patientez un moment puis réessayez.',
        AuthFailureType.networkError =>
          'Connexion au serveur impossible.\nVérifiez votre connexion internet et réessayez.',
        AuthFailureType.verificationRequired => 'Vérifiez votre adresse e-mail pour continuer.',
        AuthFailureType.accountSuspended => 'Ce compte a été suspendu.',
        AuthFailureType.accountBanned => 'Ce compte n\'a plus accès à DARNA.',
        AuthFailureType.googleSignInFailed => 'La connexion Google a échoué. Réessayez.',
        AuthFailureType.googleCancelled => 'Connexion Google annulée.',
        AuthFailureType.invalidResetCode =>
          'Ce lien est invalide ou a expiré. Demandez-en un nouveau.',
        AuthFailureType.unknown => 'Une erreur est survenue. Réessayez.',
      };

  @override
  String toString() => 'AuthFailure($type)';
}
