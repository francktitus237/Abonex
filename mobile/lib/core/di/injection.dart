import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../features/auth/data/datasources/auth_local_datasource.dart';
import '../../features/auth/data/datasources/auth_remote_datasource.dart';
import '../../features/auth/data/repositories/auth_repository_impl.dart';
import '../../features/auth/domain/repositories/auth_repository.dart';
import '../../features/auth/presentation/cubit/auth_cubit.dart';
import '../../features/auth/presentation/cubit/login_cubit.dart';
import '../../features/settings/presentation/cubit/settings_cubit.dart';
import '../../features/subscriptions/data/datasources/subscription_remote_datasource.dart';
import '../../features/subscriptions/data/repositories/subscription_repository_impl.dart';
import '../../features/subscriptions/domain/repositories/subscription_repository.dart';
import '../../features/subscriptions/presentation/cubit/subscriptions_cubit.dart';
import '../../features/workspace/data/datasources/workspace_remote_datasource.dart';
import '../network/dio_client.dart';
import '../notifications/notification_service.dart';
import '../router/app_router.dart';
import '../security/biometric_service.dart';
import '../storage/settings_storage.dart';
import '../storage/token_storage.dart';
import '../utils/currency_converter.dart';

/// Service locator unique (get_it).
/// Règle : TOUTES les dépendances sont enregistrées ici —
/// les widgets utilisent `getIt<T>()` ou `context.read<T>()`,
/// jamais `GetIt.instance` en dur dans l'arbre de widgets.
final getIt = GetIt.instance;

/// À appeler une fois dans main(), avant runApp.
Future<void> configureDependencies() async {
  // ---------- Stockage ----------
  final prefs = await SharedPreferences.getInstance();
  getIt
    ..registerSingleton<SharedPreferences>(prefs)
    ..registerSingleton<SettingsStorage>(SettingsStorage(prefs))
    ..registerSingleton<TokenStorage>(
      TokenStorage(const FlutterSecureStorage()),
    )
    ..registerSingleton<BiometricService>(BiometricService())
    ..registerSingleton<NotificationService>(NotificationService());

  // ---------- Réseau ----------
  // getIt<AuthCubit>() est résolu PARESSEUSEMENT à l'appel du callback
  // (401 sans refresh possible) — il sera déjà enregistré, pas de cycle.
  getIt.registerSingleton<Dio>(
    buildDio(
      tokenStorage: getIt<TokenStorage>(),
      onSessionExpired: () => getIt<AuthCubit>().onSessionExpired(),
    ),
  );

  // ---------- Feature : auth ----------
  getIt
    ..registerLazySingleton<AuthRemoteDataSource>(
      () => AuthRemoteDataSourceImpl(getIt()),
    )
    ..registerLazySingleton<AuthLocalDataSource>(
      () => AuthLocalDataSourceImpl(getIt()),
    )
    ..registerLazySingleton<AuthRepository>(
      () => AuthRepositoryImpl(remote: getIt(), local: getIt()),
    )
    // Singleton : la session vit tant que l'app vit.
    ..registerLazySingleton<AuthCubit>(() => AuthCubit(getIt()))
    // Factory : un nouveau cubit à chaque ouverture de la page login.
    ..registerFactory<LoginCubit>(
      () => LoginCubit(repository: getIt(), authCubit: getIt()),
    );

  // ---------- Feature : subscriptions ----------
  // Singleton : les 4 onglets partagent la même liste chargée une fois.
  getIt
    ..registerLazySingleton<SubscriptionRemoteDataSource>(
      () => SubscriptionRemoteDataSourceImpl(getIt()),
    )
    ..registerLazySingleton<SubscriptionRepository>(
      () => SubscriptionRepositoryImpl(remote: getIt()),
    )
    ..registerLazySingleton<SubscriptionsCubit>(
      () => SubscriptionsCubit(getIt()),
    );

  // ---------- Feature : workspace (setup, invites, connecteurs) ----------
  getIt
    ..registerLazySingleton<WorkspaceRemoteDataSource>(
      () => WorkspaceRemoteDataSource(getIt()),
    )
    ..registerLazySingleton<CurrencyConverter>(
      () => CurrencyConverter(getIt()),
    );

  // ---------- Feature : settings ----------
  // Singleton : le thème et la langue sont lus en continu par app.dart.
  getIt.registerLazySingleton<SettingsCubit>(
    () => SettingsCubit(storage: getIt(), biometric: getIt()),
  );

  // ---------- Routeur ----------
  // Après AuthCubit : les guards lisent son état.
  getIt.registerLazySingleton<GoRouter>(
    () => buildRouter(getIt<AuthCubit>(), getIt<SettingsStorage>()),
  );
}
