
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';

class SecurityPage extends StatefulWidget {
  const SecurityPage({super.key});

  @override
  State<SecurityPage> createState() => _SecurityPageState();
}

class _SecurityPageState extends State<SecurityPage> {
  final _formKey = GlobalKey<FormState>();

  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  static const Color navy = AppColors.navy;
  static const Color blue = AppColors.primary;

  bool _saving = false;
  bool _showCurrentPassword = false;
  bool _showNewPassword = false;
  bool _showConfirmPassword = false;

  bool get _hasPasswordProvider {
    final user = FirebaseAuth.instance.currentUser;

    return user?.providerData.any(
          (provider) => provider.providerId == 'password',
        ) ??
        false;
  }

  Future<void> _changePassword() async {
    if (_saving || !_formKey.currentState!.validate()) return;

    final user = FirebaseAuth.instance.currentUser;
    final email = user?.email;

    if (user == null || email == null || email.isEmpty) {
      _showMessage('Veuillez vous reconnecter.', isError: true);
      return;
    }

    if (!_hasPasswordProvider) {
      _showMessage(
        'Le changement de mot de passe n\'est pas disponible pour ce mode de connexion.',
        isError: true,
      );
      return;
    }

    setState(() => _saving = true);

    try {
      final credential = EmailAuthProvider.credential(
        email: email,
        password: _currentPasswordController.text,
      );

      // Confirm the user's current password.
      await user.reauthenticateWithCredential(credential);

      // Change the password in Firebase Authentication.
      await user.updatePassword(_newPasswordController.text);

      _currentPasswordController.clear();
      _newPasswordController.clear();
      _confirmPasswordController.clear();

      if (!mounted) return;

      _showMessage('Mot de passe modifié !');

      Navigator.of(context).pop();
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;

      String message;

      switch (e.code) {
        case 'wrong-password':
        case 'invalid-credential':
          message = 'Mot de passe actuel incorrect.';
          break;
        case 'weak-password':
          message = 'Le nouveau mot de passe est trop faible.';
          break;
        case 'requires-recent-login':
          message = 'Reconnectez-vous puis réessayez.';
          break;
        case 'too-many-requests':
          message = 'Trop de tentatives. Réessayez plus tard.';
          break;
        default:
          message = 'Impossible de changer le mot de passe. Réessayez.';
      }

      _showMessage(message, isError: true);
    } catch (_) {
      if (!mounted) return;

      _showMessage(
        'Une erreur est survenue. Réessayez.',
        isError: true,
      );
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  void _showMessage(
    String message, {
    bool isError = false,
  }) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
      ),
    );
  }

  Widget _passwordField({
    required String label,
    required TextEditingController controller,
    required bool visible,
    required VoidCallback onToggle,
    required String? Function(String?) validator,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: !visible,
      enableSuggestions: false,
      autocorrect: false,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: const Icon(Icons.lock_outline, color: blue),
        suffixIcon: IconButton(
          onPressed: onToggle,
          icon: Icon(
            visible ? Icons.visibility_off : Icons.visibility,
          ),
        ),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Sécurité'),
        backgroundColor: Colors.white,
        foregroundColor: navy,
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              const SizedBox(height: 12),
              const CircleAvatar(
                radius: 44,
                backgroundColor: AppColors.chip,
                child: Icon(
                  Icons.shield_outlined,
                  color: blue,
                  size: 46,
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Sécurité du compte',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: navy,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'Gérez votre mot de passe et la sécurité de votre compte.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 28),
              Card(
                color: Colors.white,
                child: ListTile(
                  leading: const Icon(
                    Icons.email_outlined,
                    color: blue,
                  ),
                  title: const Text('E-mail du compte'),
                  subtitle: Text(user?.email ?? 'Non disponible'),
                ),
              ),
              const SizedBox(height: 24),

              if (_hasPasswordProvider) ...[
                const Text(
                  'Changer le mot de passe',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: navy,
                  ),
                ),
                const SizedBox(height: 16),

                Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _passwordField(
                        label: 'Mot de passe actuel',
                        controller: _currentPasswordController,
                        visible: _showCurrentPassword,
                        onToggle: () {
                          setState(() {
                            _showCurrentPassword =
                                !_showCurrentPassword;
                          });
                        },
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Saisissez votre mot de passe actuel';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      _passwordField(
                        label: 'Nouveau mot de passe',
                        controller: _newPasswordController,
                        visible: _showNewPassword,
                        onToggle: () {
                          setState(() {
                            _showNewPassword = !_showNewPassword;
                          });
                        },
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Saisissez un nouveau mot de passe';
                          }
                          if (value.length < 8) {
                            return 'Au moins 8 caractères';
                          }
                          if (value ==
                              _currentPasswordController.text) {
                            return 'Choisissez un mot de passe différent';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      _passwordField(
                        label: 'Confirmer le nouveau mot de passe',
                        controller: _confirmPasswordController,
                        visible: _showConfirmPassword,
                        onToggle: () {
                          setState(() {
                            _showConfirmPassword =
                                !_showConfirmPassword;
                          });
                        },
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Confirmez votre nouveau mot de passe';
                          }
                          if (value != _newPasswordController.text) {
                            return 'Les mots de passe ne correspondent pas';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 28),

                      FilledButton.icon(
                        onPressed: _saving ? null : _changePassword,
                        style: FilledButton.styleFrom(
                          backgroundColor: blue,
                          padding: const EdgeInsets.all(16),
                        ),
                        icon: _saving
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.lock_reset),
                        label: Text(
                          _saving
                              ? 'Mise à jour…'
                              : 'Changer le mot de passe',
                        ),
                      ),
                    ],
                  ),
                ),
              ] else ...[
                Card(
                  color: Colors.white,
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        const Icon(
                          Icons.info_outline,
                          color: blue,
                          size: 32,
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Gestion du mot de passe',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          'Votre compte n\'utilise pas de '
                          'connexion par e-mail et mot de passe. '
                          'Si vous vous connectez avec Google, gérez '
                          'votre mot de passe depuis votre compte Google.',
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
