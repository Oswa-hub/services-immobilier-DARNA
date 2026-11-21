import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../app/routes.dart';
import '../../../../core/errors/auth_failure.dart';
import '../../../../core/theme/app_colors.dart';
import '../../providers/auth_provider.dart';
import '../widgets/auth_button.dart';
import '../widgets/auth_layout.dart';

class VerifyEmailPage extends ConsumerStatefulWidget {
  const VerifyEmailPage({super.key});

  @override
  ConsumerState<VerifyEmailPage> createState() => _VerifyEmailPageState();
}

class _VerifyEmailPageState extends ConsumerState<VerifyEmailPage> {
  static const _cooldownSeconds = 45;

  Timer? _poll;
  Timer? _tick;
  int _cooldown = _cooldownSeconds; // a mail was just sent (register) or can be resent soon
  bool _sending = false;
  bool _checking = false;

  @override
  void initState() {
    super.initState();
    _startCooldown();
    // Detect verification automatically while the page is open.
    _poll = Timer.periodic(const Duration(seconds: 4), (_) => _check(silent: true));
  }

  @override
  void dispose() {
    _poll?.cancel();
    _tick?.cancel();
    super.dispose();
  }

  void _startCooldown() {
    _tick?.cancel();
    _cooldown = _cooldownSeconds;
    _tick = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      setState(() => _cooldown = (_cooldown - 1).clamp(0, _cooldownSeconds));
      if (_cooldown == 0) t.cancel();
    });
  }

  Future<void> _check({bool silent = false}) async {
    if (_checking) return;
    _checking = true;
    if (!silent) setState(() {});
    await ref.read(authControllerProvider.notifier).refreshVerification();
    _checking = false;
    if (!mounted) return; // verified -> router already left this page
    if (!silent) {
      setState(() {});
      _snack('Votre e-mail n\'est pas encore vérifié.');
    }
  }

  Future<void> _resend() async {
    setState(() => _sending = true);
    try {
      await ref.read(authControllerProvider.notifier).sendVerificationEmail();
      if (!mounted) return;
      setState(_startCooldown);
      _snack('E-mail envoyé. Vérifiez votre boîte de réception et vos spams.');
    } on AuthFailure catch (e) {
      if (mounted) _snack(e.message);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _openMailApp() async {
    final ok = await launchUrl(Uri(scheme: 'mailto'));
    if (!ok && mounted) _snack('Aucune application de messagerie trouvée.');
  }

  void _snack(String msg) =>
      ScaffoldMessenger.of(context)..hideCurrentSnackBar()..showSnackBar(SnackBar(content: Text(msg)));

  String get _timer {
    final m = (_cooldown ~/ 60).toString().padLeft(2, '0');
    final s = (_cooldown % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final email = ref.watch(currentUserProvider)?.email ?? '';

    return AuthScaffold(
      showBack: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 24),
          const Icon(Icons.mark_email_read_outlined, size: 96, color: AppColors.primary),
          const SizedBox(height: 20),
          const Text('Vérifiez votre e-mail',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: AppColors.text)),
          const SizedBox(height: 12),
          const Text('Nous avons envoyé un lien de vérification à',
              textAlign: TextAlign.center, style: TextStyle(color: AppColors.muted)),
          const SizedBox(height: 4),
          Text(email,
              textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          const Text('Ouvrez votre boîte de réception et cliquez sur le lien pour vérifier votre compte.',
              textAlign: TextAlign.center, style: TextStyle(color: AppColors.muted)),
          const SizedBox(height: 28),
          AuthButton(label: 'Ouvrir ma messagerie', onPressed: _openMailApp),
          const SizedBox(height: 10),
          OutlinedButton(
            onPressed: _checking ? null : () => _check(),
            child: Text(_checking ? 'Vérification…' : "J'ai vérifié mon e-mail"),
          ),
          const SizedBox(height: 20),
          const Text("Vous n'avez pas reçu l'e-mail ?",
              textAlign: TextAlign.center, style: TextStyle(color: AppColors.muted)),
          TextButton(
            onPressed: (_cooldown > 0 || _sending) ? null : _resend,
            child: Text(_sending
                ? 'Envoi…'
                : _cooldown > 0
                    ? 'Renvoyer ($_timer)'
                    : 'Renvoyer'),
          ),
          // I5: the account can browse while the e-mail is not verified yet.
          TextButton(
            onPressed: () => context.go(Routes.home),
            child: const Text('Continuer sans vérifier'),
          ),
          TextButton(
            onPressed: () => ref.read(authControllerProvider.notifier).logout(),
            style: TextButton.styleFrom(foregroundColor: AppColors.muted),
            child: const Text('Utiliser un autre compte (se déconnecter)'),
          ),
        ],
      ),
    );
  }
}
