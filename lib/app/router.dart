
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/auth/presentation/pages/account_status_page.dart';
import '../features/auth/presentation/pages/forgot_password_page.dart';
import '../features/auth/presentation/pages/login_page.dart';
import '../features/auth/presentation/pages/register_page.dart';
import '../features/auth/presentation/pages/reset_password_page.dart';
import '../features/auth/presentation/pages/splash_page.dart';
import '../features/auth/presentation/pages/verify_email_page.dart';
import '../features/auth/presentation/pages/welcome_page.dart';
import '../features/agents/presentation/pages/agent_dashboard_page.dart'; // Module 10
import '../features/agents/presentation/pages/agent_inquiries_page.dart';
import '../features/agents/presentation/pages/agent_listing_detail_page.dart';
import '../features/agents/presentation/pages/agent_listings_page.dart';
import '../features/agents/presentation/pages/agent_profile_page.dart';
import '../features/agents/presentation/pages/agent_statistics_page.dart';
import '../features/agents/presentation/pages/agent_verification_page.dart';
import '../features/agents/presentation/pages/edit_agent_profile_page.dart';
import '../features/agents/presentation/pages/public_agent_profile_page.dart';
import '../features/auth/providers/auth_provider.dart';
import '../features/messaging/presentation/pages/chat_page.dart';
import '../features/messaging/presentation/pages/conversations_page.dart'; // Module 11
import '../features/map/presentation/pages/map_page.dart'; // Module 06
import '../features/profile/presentation/profile_page.dart'; // Module 02
import '../features/properties/presentation/pages/property_details_page.dart'; // Module 05
import '../features/property_discovery/presentation/screens/home_discovery_screen.dart';
import '../features/search/presentation/pages/search_page.dart'; // Module 04
import '../features/favorites/presentation/pages/favorites_page.dart'; // Module 07
import '../core/widgets/guest_gate.dart';
import '../features/publishing/presentation/pages/publish_page.dart'; // Module 08

import '../features/listings/presentation/pages/my_listings_page.dart'; // Module 09
import '../features/verification/domain/entities/verification_enums.dart'; // Module 13
import '../features/verification/presentation/admin/verification_queue_page.dart';
import '../features/verification/presentation/admin/verification_review_page.dart';
import '../features/verification/presentation/pages/verification_center_page.dart';
import '../features/verification/presentation/pages/verification_details_page.dart';
import '../features/verification/presentation/pages/verification_form_page.dart';

import '../features/notifications/presentation/pages/notification_center_page.dart'; // Module 12
import '../features/notifications/presentation/pages/notification_settings_page.dart';
import 'app_shell.dart';
import '../features/admin/presentation/admin_shell.dart'; // Module 15
import '../features/admin/presentation/pages/admin_analytics_page.dart';
import '../features/admin/presentation/pages/admin_audit_logs_page.dart';
import '../features/admin/presentation/pages/admin_dashboard_page.dart';
import '../features/admin/presentation/pages/admin_notifications_page.dart';
import '../features/admin/presentation/pages/admin_properties_page.dart';
import '../features/admin/presentation/pages/admin_reports_page.dart';
import '../features/admin/presentation/pages/admin_users_page.dart';
import '../features/content/presentation/pages/admin_content_page.dart'; // Module 16
import '../features/settings/presentation/pages/admin_settings_page.dart'; // Module 17
import '../features/settings/presentation/pages/legal_pages.dart';
import '../features/reports/presentation/pages/my_reports_page.dart'; // Module 14
import 'router_guard.dart';
import 'routes.dart';

final routerProvider = Provider<GoRouter>((ref) {
  // Re-run the redirect whenever the auth state changes.
  final refresh = ValueNotifier<int>(0);
  ref.listen(authControllerProvider, (_, _) => refresh.value++);
  ref.onDispose(refresh.dispose);

  final router = GoRouter(
    initialLocation: Routes.splash,
    refreshListenable: refresh,
    redirect: (context, state) =>
        authRedirect(ref.read(authControllerProvider), state.matchedLocation),
    routes: [
      // ---- Module 01 -------------------------------------------------------
      GoRoute(path: Routes.splash, builder: (_, _) => const SplashPage()),
      GoRoute(path: Routes.welcome, builder: (_, _) => const WelcomePage()),
      GoRoute(path: Routes.login, builder: (_, _) => const LoginPage()),
      GoRoute(path: Routes.register, builder: (_, _) => const RegisterPage()),
      GoRoute(path: Routes.forgotPassword, builder: (_, _) => const ForgotPasswordPage()),
      GoRoute(
        path: Routes.resetPassword,
        builder: (_, state) => ResetPasswordPage(code: state.uri.queryParameters['oobCode']),
      ),
      GoRoute(path: Routes.verifyEmail, builder: (_, _) => const VerifyEmailPage()),
      GoRoute(path: Routes.accountStatus, builder: (_, _) => const AccountStatusPage()),
      // ---- Module 15 / 16 / 17: admin panel ---------------------------------
      ShellRoute(
        builder: (_, state, child) => AdminShell(location: state.uri.path, child: child),
        routes: [
          GoRoute(path: Routes.adminDashboard, builder: (_, _) => const AdminDashboardPage()),
          GoRoute(path: Routes.adminUsers, builder: (_, _) => const AdminUsersPage()),
          GoRoute(path: Routes.adminProperties, builder: (_, _) => const AdminPropertiesPage()),
          GoRoute(path: Routes.adminReports, builder: (_, _) => const AdminReportsPage()),
          GoRoute(path: Routes.adminNotifications, builder: (_, _) => const AdminNotificationsPage()),
          GoRoute(path: Routes.adminContent, builder: (_, _) => const AdminContentPage()),
          GoRoute(path: Routes.adminAnalytics, builder: (_, _) => const AdminAnalyticsPage()),
          GoRoute(path: Routes.adminSettings, builder: (_, _) => const AdminSettingsPage()),
          GoRoute(path: Routes.adminAuditLogs, builder: (_, _) => const AdminAuditLogsPage()),
        ],
      ),
      // ---- Module 14: Reports & Safety --------------------------------------
      GoRoute(path: Routes.myReports, builder: (_, _) => const MyReportsPage()),
      // ---- Module 17: public information pages ------------------------------
      GoRoute(path: Routes.legalTerms, builder: (_, _) => const LegalPage(document: LegalDocument.terms)),
      GoRoute(path: Routes.legalPrivacy, builder: (_, _) => const LegalPage(document: LegalDocument.privacy)),
      GoRoute(path: Routes.contact, builder: (_, _) => const ContactPage()),
      // Module 13 admin review. Under /admin: the router guard keeps non-admins
      // out, and the Firestore rules refuse their reads anyway.
      GoRoute(path: Routes.adminVerification, builder: (_, _) => const VerificationQueuePage()),
      GoRoute(
        path: Routes.adminVerificationReviewPattern,
        builder: (_, state) => VerificationReviewPage(verificationId: state.pathParameters['id'] ?? ''),
      ),

      // ---- Main app: bottom navigation ------------------------------------
      StatefulShellRoute.indexedStack(
        builder: (_, _, shell) => AppShell(shell: shell),
        branches: [
          StatefulShellBranch(routes: [
            GoRoute(path: Routes.home, builder: (_, _) => const HomeDiscoveryScreen()), // Module 03
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: Routes.search,
              builder: (_, state) => SearchPage(params: state.uri.queryParameters),
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: Routes.map,
              builder: (_, state) => MapPage(params: state.uri.queryParameters), // Module 06
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: Routes.favorites,
              builder: (_, _) => const GuestGate.favorites(child: FavoritesPage()), // Module 07
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: Routes.profile, builder: (_, _) => const GuestGate.profile(child: UserProfilePage())), // Module 02
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: Routes.messages,
              builder: (_, _) => const GuestGate.messages(child: ConversationsPage()), // Module 11
            ),
          ]),
        ],
      ),

      // ---- Full-screen pages pushed on top of the shell --------------------
      GoRoute(
        path: Routes.propertyDetailsPattern,
        builder: (_, state) => PropertyDetailsPage(propertyId: state.pathParameters['id'] ?? ''),
      ),
      // ---- Module 10: Agent / Agency ---------------------------------------
      GoRoute(
        path: Routes.agentDashboard,
        builder: (_, _) => const AgentDashboardPage(),
        routes: [
          GoRoute(path: 'setup', builder: (_, _) => const EditAgentProfilePage(setup: true)),
          GoRoute(
            path: 'profile',
            builder: (_, _) => const AgentProfilePage(),
            routes: [GoRoute(path: 'edit', builder: (_, _) => const EditAgentProfilePage(setup: false))],
          ),
          GoRoute(
            path: 'listings',
            builder: (_, _) => const AgentListingsPage(),
            routes: [
              GoRoute(
                path: ':propertyId',
                builder: (_, state) => AgentListingDetailPage(propertyId: state.pathParameters['propertyId'] ?? ''),
              ),
            ],
          ),
          GoRoute(path: 'inquiries', builder: (_, _) => const AgentInquiriesPage()),
          GoRoute(path: 'statistics', builder: (_, _) => const AgentStatisticsPage()),
          GoRoute(path: 'verification', builder: (_, _) => const AgentVerificationPage()),
        ],
      ),
      GoRoute(
        path: Routes.agentPublicPattern,
        builder: (_, state) => PublicAgentProfilePage(agentId: state.pathParameters['agentId'] ?? ''),
      ),
      GoRoute(
        path: Routes.chatPattern,
        builder: (_, state) => ChatPage(conversationId: state.pathParameters['conversationId'] ?? ''),
      ),
      // ---- Module 13: Verification (applicant) -----------------------------
      GoRoute(
        path: Routes.verification,
        builder: (_, _) => const VerificationCenterPage(),
        routes: [
          GoRoute(
            path: 'new/:type/:targetId',
            builder: (_, state) {
              final type = VerificationTargetType.tryParse(state.pathParameters['type']);
              final targetId = state.pathParameters['targetId'] ?? '';
              if (type == null) return const VerificationCenterPage();
              return VerificationFormPage(targetType: type, targetId: targetId);
            },
          ),
          GoRoute(
            path: ':id',
            builder: (_, state) => VerificationDetailsPage(verificationId: state.pathParameters['id'] ?? ''),
          ),
        ],
      ),
      GoRoute(
        path: Routes.publish,
        builder: (_, _) => const PublishPage(), // Module 08
      ),
      GoRoute(
        path: Routes.myListings,
        builder: (_, _) => const MyListingsPage(),
      ),
      // ---- Module 12: Notifications ---------------------------------------
      GoRoute(
        path: Routes.notifications,
        builder: (_, _) => const NotificationCenterPage(),
        routes: [
          GoRoute(path: 'settings', builder: (_, _) => const NotificationSettingsPage()),
        ],
      ),
    ],
  );
  ref.onDispose(router.dispose);
  return router;
});