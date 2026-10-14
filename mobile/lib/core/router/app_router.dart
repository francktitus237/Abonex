import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/domain/entities/user.dart';
import '../../features/auth/presentation/cubit/auth_cubit.dart';
import '../../features/auth/presentation/cubit/auth_state.dart';
import '../../features/auth/presentation/pages/login_page.dart';
import '../../features/auth/presentation/pages/onboarding_page.dart';
import '../../features/auth/presentation/pages/register_page.dart';
import '../../features/calendar/presentation/pages/calendar_page.dart';
import '../../features/dashboard/presentation/pages/dashboard_page.dart';
import '../../features/notifications/presentation/pages/notifications_page.dart';
import '../../features/profile/presentation/pages/profile_page.dart';
import '../../features/reports/presentation/pages/reports_page.dart';
import '../../features/subscriptions/presentation/pages/subscription_detail_page.dart';
import '../../features/subscriptions/presentation/pages/subscriptions_page.dart';
import '../../features/users/presentation/pages/users_page.dart';
import '../storage/settings_storage.dart';
import '../widgets/app_shell.dart';
import '../widgets/splash_page.dart';

/// Chemins centralisés : jamais de chaîne d'URL en dur ailleurs.
/// Renommer une route = une seule ligne à changer.
abstract final class AppRoutes {
  static const splash = '/splash';
  static const onboarding = '/onboarding';
  static const login = '/login';
  static const register = '/register';
  static const home = '/';
  static const subscriptions = '/subscriptions';
  static const calendar = '/calendar';
  static const reports = '/reports';
  static const profile = '/profile';

  /// Réservé au Propriétaire — voir le guard dans `redirect`.
  static const users = '/users';

  /// Centre de notifications in-app.
  static const notifications = '/notifications';

  /// Détail d'un abonnement — `/subscriptions/42`.
  static String subscriptionDetail(String id) => '/subscriptions/$id';
}

/// Routeur unique de l'application.
///
/// Le `redirect` est le GUARD côté UI (le CDC exige que la sécurité
/// réelle reste côté Django — ici on masque seulement l'interface) :
/// - pas de session → /login
/// - session active sur /login → /
/// - /users → réservé au Propriétaire
GoRouter buildRouter(AuthCubit authCubit, SettingsStorage settingsStorage) {
  return GoRouter(
    initialLocation: AppRoutes.splash,
    // Le routeur réévalue ses guards à chaque changement d'état d'auth
    // (login, logout, session expirée par l'intercepteur Dio).
    refreshListenable: _AuthListenable(authCubit),
    redirect: (context, state) {
      final location = state.matchedLocation;
      final onPublicAuth =
          location == AppRoutes.login || location == AppRoutes.register;
      final onOnboarding = location == AppRoutes.onboarding;

      return switch (authCubit.state) {
        // Session en cours de restauration : on reste sur le splash.
        AuthUnknown() => location == AppRoutes.splash
            ? null
            : AppRoutes.splash,
        Unauthenticated() => () {
          if (location == AppRoutes.splash) {
            return settingsStorage.onboardingSeen
                ? AppRoutes.login
                : AppRoutes.onboarding;
          }
          if (!settingsStorage.onboardingSeen && !onOnboarding) {
            return AppRoutes.onboarding;
          }
          if (onOnboarding || onPublicAuth) return null;
          return AppRoutes.login;
        }(),
        Authenticated(user: final user) => () {
          if (onPublicAuth || onOnboarding || location == AppRoutes.splash) {
            return AppRoutes.home;
          }
          // Guard par rôle, exigence CDC.
          if (state.matchedLocation == AppRoutes.users &&
              !user.role.canManageUsers) {
            return AppRoutes.home;
          }
          return null;
        }(),
      };
    },
    routes: [
      GoRoute(
        path: AppRoutes.splash,
        builder: (_, _) => const SplashPage(),
      ),
      GoRoute(
        path: AppRoutes.onboarding,
        builder: (_, _) => const OnboardingPage(),
      ),
      GoRoute(path: AppRoutes.login, builder: (_, _) => const LoginPage()),
      GoRoute(
        path: AppRoutes.register,
        builder: (_, _) => const RegisterPage(),
      ),

      // --- Shell à 5 onglets (l'état de chaque branche est préservé) ---
      StatefulShellRoute.indexedStack(
        builder: (_, _, shell) => AppShell(shell: shell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.home,
                builder: (_, _) => const DashboardPage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.subscriptions,
                builder: (_, _) => const SubscriptionsPage(),
                routes: [
                  GoRoute(
                    path: ':id',
                    builder: (_, state) => SubscriptionDetailPage(
                      subscriptionId: state.pathParameters['id']!,
                    ),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.calendar,
                builder: (_, _) => const CalendarPage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.reports,
                builder: (_, _) => const ReportsPage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.profile,
                builder: (_, _) => const ProfilePage(),
              ),
            ],
          ),
        ],
      ),

      // --- Routes hors onglets ---
      GoRoute(path: AppRoutes.users, builder: (_, _) => const UsersPage()),
      GoRoute(
        path: AppRoutes.notifications,
        builder: (_, _) => const NotificationsPage(),
      ),
    ],
  );
}

/// Pont Cubit → Listenable : refreshListenable de GoRouter n'accepte
/// que des Listenable, pas des Stream. Ce wrapper notifie le routeur
/// à chaque nouvel état d'auth.
final class _AuthListenable extends ChangeNotifier {
  _AuthListenable(AuthCubit cubit) {
    _subscription = cubit.stream.listen((_) => notifyListeners());
  }

  late final StreamSubscription<AuthState> _subscription;

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}
