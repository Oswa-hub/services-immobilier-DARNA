import '../features/auth/domain/entities/auth_user.dart';
import '../features/auth/providers/auth_state.dart';
import 'routes.dart';

/// true  = a signed-out visitor first sees the welcome page (it has an
///         "Explorer les biens" button that enters the app without an account)
/// false = a signed-out visitor lands directly on the Accueil
const bool welcomeFirst = false;

/// Guests can browse without an account. The Favoris / Messages / Profil tabs
/// are reachable too (they show a "Se connecter" panel, see GuestGate).
/// Only publishing and admin ask for a login.
bool _guestCanOpen(String location) =>
    Routes.publicRoutes.contains(location) ||
    location == Routes.home ||
    location == Routes.search ||
    location == Routes.map ||
    location == Routes.favorites ||
    location == Routes.messages ||
    location == Routes.profile ||
    location == Routes.legalTerms || // Module 17
    location == Routes.legalPrivacy ||
    location == Routes.contact ||
    location.startsWith('/property/') ||
    location.startsWith('/agents/'); // public professional profile

/// I4: where to return after signing in. Only an in-app page a signed-in user
/// may open: never an external URL, an auth page or (for non-admins) /admin.
String? _safeReturn(String? from, AuthUser user) {
  if (from == null || !from.startsWith('/') || from.startsWith('//')) return null;
  final path = Uri.tryParse(from)?.path ?? from;
  if (_authPages.contains(path)) return null;
  if (path.startsWith('/admin') && !user.isAdmin) return null;
  return from;
}

const _authPages = {
  Routes.splash,
  Routes.welcome,
  Routes.login,
  Routes.register,
  Routes.forgotPassword,
  Routes.verifyEmail,
  Routes.accountStatus,
};

/// Pure redirect logic for go_router (spec §31). Returns the location to
/// redirect to, or null to allow [location]. [from] is the `?from=` of the
/// login / register page (I4). Unit-tested.
String? authRedirect(AuthState state, String location, {String? from}) {
  // The reset link must work whatever the session looks like.
  if (location == Routes.resetPassword) return null;

  String? go(String target) => location == target ? null : target;

  switch (state) {
    case AuthInitializing():
      return go(Routes.splash);

    case AuthUnauthenticated() || AuthAuthenticating() || AuthError():
      if (location == Routes.splash) return welcomeFirst ? Routes.welcome : Routes.home;
      return _guestCanOpen(location) ? null : Routes.login;

    case AuthEmailVerificationRequired(:final user):
      if (user.isBlocked) return go(Routes.accountStatus);
      // I5: until the e-mail is verified the account browses like a visitor;
      // publishing and the professional pages still need the verification.
      if (location == Routes.verifyEmail) return null;
      if (location == Routes.splash || location == Routes.login || location == Routes.register) {
        return Routes.verifyEmail;
      }
      if (_authPages.contains(location)) return go(Routes.verifyEmail);
      return _guestCanOpen(location) ? null : Routes.verifyEmail;

    case AuthAuthenticated(:final user):
      if (user.isBlocked) return go(Routes.accountStatus);

      if (_authPages.contains(location)) return _safeReturn(from, user) ?? homeFor(user);

      if (location.startsWith('/admin') && !user.isAdmin) return Routes.home;
      return null;
  }
}

String homeFor(AuthUser user) => user.isAdmin ? Routes.adminDashboard : Routes.home;
