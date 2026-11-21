import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router_guard.dart';
import '../../../../app/routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/validators.dart';
import '../../../../core/widgets/app_logo.dart';
import '../../providers/auth_provider.dart';
import '../../providers/auth_state.dart';
import '../widgets/auth_button.dart';
import '../widgets/auth_error_message.dart';
import '../widgets/auth_layout.dart';
import '../widgets/auth_text_field.dart';
import '../widgets/google_sign_in_button.dart';
import '../widgets/password_field.dart';

class RegisterPage extends ConsumerStatefulWidget {
  const RegisterPage({super.key});

  @override
  ConsumerState<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends ConsumerState<RegisterPage> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();

  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(authControllerProvider.notifier).clearError());
  }

  @override
  void dispose() {
    for (final c in [_name, _email, _phone, _password, _confirm]) {
      c.dispose();
    }
    super.dispose();
  }

  void _submit() {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;
    ref.read(authControllerProvider.notifier).register(
          name: _name.text,
          email: _email.text,
          phone: Validators.normalizePhone(_phone.text),
          password: _password.text,
        );
  }

  @override
  Widget build(BuildContext context) {
    // The login/register page may be pushed on top of Home (guest flow), so the
    // router redirect alone can leave it on screen. Leave it explicitly once signed in.
    ref.listen<AuthState>(authControllerProvider, (_, next) {
      if (next is AuthAuthenticated) context.go(homeFor(next.user));
    });

    final loading = ref.watch(authControllerProvider) is AuthAuthenticating;

    return AuthScaffold(
      child: AutofillGroup(
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Center(child: AppLogo(size: 48)),
              const SizedBox(height: 20),
              const Text('Créer votre compte',
                  style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: AppColors.text)),
              const SizedBox(height: 6),
              const Text('Rejoignez DARNA et trouvez votre prochain bien en Tunisie.',
                  style: TextStyle(color: AppColors.muted)),
              const SizedBox(height: 22),
              const AuthErrorMessage(),
              AuthTextField(
                controller: _name,
                hint: 'Nom complet',
                icon: Icons.person_outline,
                autofillHints: const [AutofillHints.name],
                validator: Validators.fullName,
                enabled: !loading,
              ),
              const SizedBox(height: 12),
              AuthTextField(
                controller: _email,
                hint: 'Adresse e-mail',
                icon: Icons.mail_outline,
                keyboardType: TextInputType.emailAddress,
                autofillHints: const [AutofillHints.email],
                validator: Validators.email,
                enabled: !loading,
              ),
              const SizedBox(height: 12),
              AuthTextField(
                controller: _phone,
                hint: 'Téléphone (ex. 22 123 456)',
                icon: Icons.phone_outlined,
                keyboardType: TextInputType.phone,
                autofillHints: const [AutofillHints.telephoneNumber],
                validator: Validators.phone,
                enabled: !loading,
              ),
              const SizedBox(height: 12),
              PasswordField(
                controller: _password,
                validator: Validators.password,
                newPassword: true,
                enabled: !loading,
              ),
              const SizedBox(height: 12),
              PasswordField(
                controller: _confirm,
                hint: 'Confirmer le mot de passe',
                validator: (v) => Validators.confirmPassword(v, _password.text),
                newPassword: true,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _submit(),
                enabled: !loading,
              ),
              const SizedBox(height: 20),
              AuthButton(label: 'Créer mon compte', loading: loading, onPressed: _submit),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('Déjà un compte ?', style: TextStyle(color: AppColors.muted)),
                  TextButton(
                    onPressed: loading ? null : () => context.pushReplacement(Routes.login),
                    child: const Text('Se connecter'),
                  ),
                ],
              ),
              const OrDivider(),
              GoogleSignInButton(
                disabled: loading,
                onPressed: ref.read(authControllerProvider.notifier).signInWithGoogle,
              ),
              const SizedBox(height: 16),
              const Text(
                'En créant un compte, vous acceptez nos conditions d\'utilisation et notre politique de confidentialité.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 11, color: AppColors.muted),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
