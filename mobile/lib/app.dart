import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:go_router/go_router.dart';
import 'package:toastification/toastification.dart';

import 'core/di/injection.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/presentation/cubit/auth_cubit.dart';
import 'features/settings/presentation/cubit/settings_cubit.dart';
import 'features/settings/presentation/cubit/settings_state.dart';
import 'features/subscriptions/presentation/cubit/subscriptions_cubit.dart';

/// Widget racine. AUCUNE logique métier ici :
/// uniquement la configuration du MaterialApp et des providers globaux.
class AbonexApp extends StatelessWidget {
  const AbonexApp({super.key});

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
