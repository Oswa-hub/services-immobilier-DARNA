import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/routes.dart';
import '../../../../core/errors/auth_failure.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/validators.dart';
import '../../providers/auth_provider.dart';
import '../widgets/auth_button.dart';
import '../widgets/auth_error_message.dart';
import '../widgets/auth_layout.dart';
import '../widgets/password_field.dart';

/// Opened from the reset email via `/reset-password?oobCode=...`
/// (requires the deep-link / action-URL setup described in the README).
class ResetPasswordPage extends ConsumerStatefulWidget {
  const ResetPasswordPage({super.key, this.code});

  final String? code;

  @override
  ConsumerState<ResetPasswordPage> createState() => _ResetPasswordPageState();
}

class _ResetPasswordPageState extends ConsumerState<ResetPasswordPage> {
  final _formKey = GlobalKey<FormState>();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await ref
          .read(authControllerProvider.notifier)
          .confirmPasswordReset(code: widget.code!, newPassword: _password.text);
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Mot de passe modifié. Vous pouvez vous connecter.')));
      context.go(Routes.login);
    } on AuthFailure catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasCode = widget.code != null && widget.code!.isNotEmpty;
    final rules = Validators.passwordRules(_password.text);

    return AuthScaffold(
      child: !hasCode
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 24),
                const AuthErrorMessage(
                    message: 'Ce lien est invalide ou a expiré. Demandez-en un nouveau.'),
                AuthButton(label: 'Demander un nouveau lien', onPressed: () => context.go(Routes.forgotPassword)),
              ],
            )
          : Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 16),
                  const Icon(Icons.verified_user_outlined, size: 88, color: AppColors.primary),
                  const SizedBox(height: 20),
                  const Text('Nouveau mot de passe',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: AppColors.text)),
                  const SizedBox(height: 10),
                  const Text('Choisissez un mot de passe solide pour protéger votre compte.',
                      textAlign: TextAlign.center, style: TextStyle(color: AppColors.muted)),
                  const SizedBox(height: 24),
                  AuthErrorMessage(message: _error),
                  PasswordField(
                    controller: _password,
                    hint: 'Nouveau mot de passe',
                    validator: Validators.password,
                    newPassword: true,
                    onChanged: (_) => setState(() {}),
                    enabled: !_loading,
                  ),
                  const SizedBox(height: 12),
                  PasswordField(
                    controller: _confirm,
                    hint: 'Confirmer le mot de passe',
                    validator: (v) => Validators.confirmPassword(v, _password.text),
                    newPassword: true,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _submit(),
                    enabled: !_loading,
                  ),
                  const SizedBox(height: 16),
                  _Rule('Au moins ${Validators.minPasswordLength} caractères', rules.minLength),
                  _Rule('Une lettre majuscule', rules.uppercase),
                  _Rule('Un chiffre', rules.number),
                  const SizedBox(height: 20),
                  AuthButton(label: 'Réinitialiser le mot de passe', loading: _loading, onPressed: _submit),
                ],
              ),
            ),
    );
  }
}

class _Rule extends StatelessWidget {
  const _Rule(this.text, this.ok);
  final String text;
  final bool ok;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(children: [
          Icon(ok ? Icons.check_circle : Icons.radio_button_unchecked,
              size: 18, color: ok ? AppColors.success : AppColors.muted),
          const SizedBox(width: 8),
          Text(text, style: const TextStyle(fontSize: 13, color: AppColors.muted)),
        ]),
      );
}
