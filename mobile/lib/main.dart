import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import 'app.dart';
import 'core/config/env.dart';
import 'core/di/injection.dart';
import 'core/notifications/notification_service.dart';
import 'features/auth/presentation/cubit/auth_cubit.dart';

Future<void> main() async {
  // Obligatoire avant tout appel à du code natif (stockage sécurisé,
  // biométrie, notifications…) effectué avant runApp.
  WidgetsFlutterBinding.ensureInitialized();

  // Formats de date/nombre en français (intl) — affichage Africa/Douala.
  await initializeDateFormatting('fr');

  // Injection de dépendances : stockage, réseau, repositories, cubits, router.
  await configureDependencies();

  // Rappels locaux d'échéances — best effort : si la permission
  // est refusée ou le canal indisponible, l'app démarre quand même.
  try {
    await getIt<NotificationService>().init();
  } catch (_) {}

  // Restauration de session AVANT le premier frame : le guard du router
  // sait immédiatement si l'utilisateur est connecté — pas de flash
  // de l'écran de connexion pour une session valide.
  // Le try/catch est obligatoire : si le stockage sécurisé est illisible
  // (contexte non sécurisé, données corrompues…), on démarre quand même
  // en "non connecté" plutôt que de laisser l'app sur un écran blanc.
  try {
    await getIt<AuthCubit>().bootstrap();
  } catch (_) {
    getIt<AuthCubit>().onSessionExpired();
  }

  if (Env.sentryDsn.isNotEmpty) {
    // Crash-reporting activé uniquement si un DSN est fourni via
    // --dart-define=SENTRY_DSN=... — jamais de secret en dur.
    await SentryFlutter.init(
      (options) => options.dsn = Env.sentryDsn,
      appRunner: () => runApp(const AbonexApp()),
    );
  } else {
    runApp(const AbonexApp());
  }
}
