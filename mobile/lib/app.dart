import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:go_router/go_router.dart';
import 'package:toastification/toastification.dart';

import 'core/di/injection.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/presentation/cubit/auth_cubit.dart';
import 'features/settings/presentation/cubit/settings_cubit.dart';
import 'features/settings/presentation/cubit/settings_state.dart';
import 'features/subscriptions/presentation/cubit/subscriptions_cubit.dart';

/// Widget racine. AUCUNE logique métier ici :
/// uniquement la configuration du MaterialApp, des providers
/// globaux et de l'écoute des deep links abonex://*.
class AbonexApp extends StatefulWidget {
  const AbonexApp({super.key});

  @override
  State<AbonexApp> createState() => _AbonexAppState();
}

class _AbonexAppState extends State<AbonexApp> {
  final _appLinks = AppLinks();
  StreamSubscription<Uri>? _linkSub;

  @override
  void initState() {
    super.initState();
    // Liens froids (app lancée par un clic d'email) et chauds
    // (app déjà ouverte). Erreurs ignorées : un lien malformé
    // ne doit pas empêcher le démarrage.
    _appLinks.getInitialLink().then(_handleLink).catchError((_) {});
    _linkSub = _appLinks.uriLinkStream.listen(
      _handleLink,
      onError: (_) {},
    );
  }

  /// `abonex://invite/<token>` → page d'invitation pré-remplie ;
  /// `abonex://reset/<uid>/<token>` → réinitialisation du mot
  /// de passe. Le host filtré dans le manifeste garantit que le
  /// callback Powens n'arrive jamais ici.
  void _handleLink(Uri? uri) {
    if (uri == null || uri.scheme != 'abonex') return;
    final router = getIt<GoRouter>();
    switch (uri.host) {
      case 'invite':
        final token = uri.pathSegments.isEmpty ? '' : uri.pathSegments[0];
        if (token.isNotEmpty) {
          router.go('${AppRoutes.inviteAccept}?token=${Uri.encodeComponent(token)}');
        } else {
          router.go(AppRoutes.inviteAccept);
        }
      case 'reset':
        if (uri.pathSegments.length >= 2) {
          router.go(
            '${AppRoutes.resetPassword}'
            '?uid=${Uri.encodeComponent(uri.pathSegments[0])}'
            '&token=${Uri.encodeComponent(uri.pathSegments[1])}',
          );
        } else {
          router.go(AppRoutes.resetPassword);
        }
    }
  }

  @override
  void dispose() {
    _linkSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        // Session : accessible via context.read<AuthCubit>() partout.
        BlocProvider<AuthCubit>.value(value: getIt<AuthCubit>()),
        // Réglages : thème et langue réactifs (voir BlocBuilder plus bas).
        BlocProvider<SettingsCubit>.value(value: getIt<SettingsCubit>()),
        // Abonnements : une seule source partagée par les 4 onglets.
        BlocProvider<SubscriptionsCubit>.value(
          value: getIt<SubscriptionsCubit>(),
        ),
      ],
      // Rebuild du MaterialApp quand thème/langue changent.
      child: BlocBuilder<SettingsCubit, SettingsState>(
        builder: (context, settings) {
          // Requis par toastification pour afficher les toasts.
          return ToastificationWrapper(
            child: MaterialApp.router(
              title: 'Abonex',
              debugShowCheckedModeBanner: false,

              theme: AppTheme.light(),
              darkTheme: AppTheme.dark(),
              themeMode: settings.themeMode,

              routerConfig: getIt<GoRouter>(),

              // FR par défaut, EN ensuite — exigence du cahier des charges.
              supportedLocales: const [Locale('fr'), Locale('en')],
              locale: settings.locale,
              localizationsDelegates: const [
                GlobalMaterialLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
              ],
            ),
          );
        },
      ),
    );
  }
}
