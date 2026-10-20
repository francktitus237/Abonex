# Abonex — Application mobile (Flutter)

Application Flutter du gestionnaire de dépenses récurrentes Abonex.
Android 8.0+ — se connecte à l'API Django `/api/v1`.

## Démarrage

```bash
cd mobile
flutter pub get
dart run build_runner build --delete-conflicting-outputs
flutter run --dart-define=API_BASE_URL=http://<ip-locale>:8000/api/v1
```

## Build de l'APK de production

```bash
flutter build apk --release \
  --dart-define=API_BASE_URL=https://abonex.aiforge.world/api/v1
```

Résultat : `build/app/outputs/flutter-apk/app-release.apk`
(la CI `.github/workflows/apk.yml` le produit aussi automatiquement).

### `--dart-define` acceptés

| Clé | Rôle | Défaut |
|---|---|---|
| `API_BASE_URL` | URL de l'API | `http://192.168.137.1:8000/api/v1` |
| `SENTRY_DSN` | Monitoring des erreurs | désactivé |

## Architecture

Clean Architecture par features — chaque feature a
`data/` (datasources, modèles, repositories), `domain/` (entités,
contrats de repository, use-cases) et `presentation/` (pages, cubits).

```
lib/
├── app.dart                    # MaterialApp, thème, locale
├── core/
│   ├── di/injection.dart       # GetIt — enregistre datasources, repos, cubits
│   ├── network/api_endpoints.dart  # TOUTES les routes /api/v1 — jamais de chemin en dur ailleurs
│   ├── network/dio_client.dart # Dio + intercepteur JWT (refresh auto)
│   ├── data/countries.dart     # Pays → devise/langue suggérées
│   ├── utils/formatters.dart   # money(amount, currency) multi-devises
│   ├── utils/currency_converter.dart # Conversion via /rates/ → devise locale
│   ├── storage/settings_storage.dart   # Préférences non sensibles (thème, rappels…)
│   ├── storage/token_storage.dart      # JWT + user cache (flutter_secure_storage)
│   ├── notifications/          # flutter_local_notifications + canaux alarme
│   └── router/app_router.dart  # GoRouter : shell 5 onglets + routes racine
└── features/
    ├── auth/        # login, register, onboarding, acceptation d'invitation
    ├── dashboard/   # totaux convertis en devise locale, budget, alertes
    ├── subscriptions/ # CRUD, détail, historique paiements, import
    ├── calendar/    # échéances par jour
    ├── reports/     # graphiques filtrés par devise
    ├── profile/     # rôles, thème, langue, rappels, budget
    ├── notifications/ # centre de notifications
    └── workspace/   # setup pays/devises, invitations, intégrations
```

## Règles importantes

- **URL d'API** : uniquement via `ApiEndpoints` — jamais de route en dur
- **Devises** : jamais de `FCFA` en dur ; toujours `AppFormatters.money(x, currency)` et `subscription.currency`
- **Totaux** : jamais additionner deux devises — passer par
  `CurrencyConverter` vers `workspace.defaultCurrency`
- **Sécurité** : tokens dans `TokenStorage` (secure) ; `SettingsStorage`
  (SharedPreferences) uniquement pour les préférences. Les contrôles de
  rôle côté client masquent l'UI — Django applique les permissions.
- **État** : BLoC/Cubit ; datasources → repositories (convertissent les
  `DioException` en `Failure`) → cubits → UI

## Intégrations

- **Connecteurs fournisseurs** : page Intégrations — clés API des
  comptes externes (OVH, Stripe…), synchro et déconnexion.
- **Agrégation bancaire** : « Connecter ma banque » ouvre le webview
  OAuth Powens (`flutter_web_auth_2`) ; la redirection revient via
  le deep-link `abonex://powens/callback` (intent-filter Android
  déclaré dans `AndroidManifest.xml`).
- **Mise à jour** : tuile Profil → compare la version installée
  (`package_info_plus`) avec `GET /meta/app-version/` et propose
  le téléchargement (`url_launcher`).

## Tests

```bash
flutter analyze
flutter test
```
