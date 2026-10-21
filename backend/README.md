# Backend Abonex — API Django REST

API REST sécurisée (JWT) pour l'application Abonex.
Toutes les routes sont préfixées par `/api/v1/`.

## Installation locale

```bash
python -m venv .venv
.venv/Scripts/activate          # Windows
# source .venv/bin/activate     # Linux/macOS
pip install -r requirements.txt
python manage.py migrate
python manage.py seed           # compte demo + abonnements d'exemple
python manage.py runserver 0.0.0.0:8000
```

Compte seed : `demo@abonex.app` (mot de passe dans `api/management/commands/seed.py`).

## Variables d'environnement

Voir `backend/.env.example` pour le fichier complet et
`DEPLOYMENT.md` (racine du dépôt) pour la mise en production.

| Variable | Défaut | Rôle |
|---|---|---|
| `DJANGO_DEBUG` | `true` en dev | Mode debug — `false` en prod |
| `DJANGO_SECRET_KEY` | — | Clé secrète Django (obligatoire en prod) |
| `DJANGO_ALLOWED_HOSTS` | `*` en DEBUG | Hôtes autorisés, séparés par `,` |
| `PROVIDER_SECRET_KEY` | dérivée de SECRET_KEY | Clé Fernet pour identifiants/tokens fournisseurs |
| `POWENS_CLIENT_ID`, `POWENS_CLIENT_SECRET`, `POWENS_DOMAIN` | sandbox | Agrégation bancaire PSD2 (OAuth) |
| `APP_LATEST_VERSION`, `APP_UPDATE_URL` | — | Bouton « Mettre à jour » du profil |
| `EMAIL_HOST`, `EMAIL_PORT`, `EMAIL_HOST_USER`, `EMAIL_HOST_PASSWORD` | console | SMTP pour les invitations par e-mail |
| `RATES_CONVERT_URL`… | frankfurter.dev | Source des taux de change |

## Démonstrations régionales au déploiement

Pour remplir les espaces de `demo.cm@abonex.app` (XAF) et
`demo.fr@abonex.app` (EUR), activer `DEMO_SEED_ENABLED=true` dans Dokploy.
`entrypoint.sh` exécute alors `python manage.py seed --regional-demo`
après les migrations. Si un compte doit être créé, fournir aussi
`DEMO_SEED_PASSWORD` (12 caractères minimum) via les variables sécurisées.
Les mots de passe des comptes existants ne sont jamais réinitialisés.

Chaque espace reçoit 10 abonnements/factures, 3 rendez-vous, 2 paiements
fictifs et un budget mensuel (1 500 000 XAF ou 6 000 EUR). Les dates sont
relatives au premier remplissage. Les données existantes portant le même
nom et un budget déjà défini sont conservés. Le marqueur `demo_seeded_at`
empêche toute réinitialisation lors des déploiements suivants, même si
l'utilisateur a renommé ou supprimé des exemples. Aucun fournisseur réel
n'est connecté et aucun paiement réel n'est effectué. Les espaces partagés
ou incompatibles sont ignorés plutôt que modifiés ; un avertissement précise
les motifs (rôle, partage, pays ou devise). Le remplissage démo est optionnel :
son échec est journalisé mais ne bloque pas le démarrage de l'API. Les erreurs
de migration restent bloquantes. Vérifier les logs pour confirmer le remplissage
réel de chacun des deux comptes.

Le budget est accessible par `GET/PATCH /api/v1/workspace/budget/` ; seuls
les propriétaires et gestionnaires peuvent le modifier. Un client mobile
recompilé avec cette fonctionnalité est nécessaire pour l'afficher ; les
anciens APK utilisent encore leur budget local.

## Modèles principaux

| Modèle | Rôle |
|---|---|
| `User` | Compte (JWT), `role`, `language` |
| `Workspace` | Espace de travail : `country`, `defaultCurrency`, `extraCurrencies`, `configured` |
| `Subscription` | Abonnement : `amount`, `currency`, `cycle` (monthly/quarterly/yearly/once), `startDate`, `endDate`, `nextDueDate`, `status` |
| `Payment` | Historique des paiements |
| `Invitation` | Invitation par e-mail avec token unique + expiration |
| `ProviderConnection` | Connexion à un fournisseur externe, identifiants chiffrés Fernet |

## Routes API (`/api/v1/`)

### Auth
| Méthode | Route | Description |
|---|---|---|
| POST | `auth/register/` | Inscription — crée le workspace, rôle `owner` |
| POST | `auth/login/` | Connexion, retourne access + refresh JWT |
| POST | `auth/token/refresh/` | Rotation du refresh token |
| POST | `auth/logout/` | Blackliste le refresh token |
| GET | `auth/me/` | Utilisateur + workspace courant |
| POST | `auth/password/forgot/` / `auth/password/reset/` | Réinitialisation |

### Abonnements
| Méthode | Route | Description |
|---|---|---|
| GET/POST | `subscriptions/` | Liste / création (filtrée par workspace) |
| GET/PATCH/DELETE | `subscriptions/<id>/` | Détail, mise à jour, suppression |
| GET | `subscriptions/<id>/history/` | Historique des paiements |
| POST | `subscriptions/bulk/` | Import en masse (max 500 lignes) |

### Workspace, invitations, intégrations
| Méthode | Route | Description |
|---|---|---|
| POST | `workspace/setup/` | Pays, langue, devises, rôle → `configured=true` |
| POST | `invites/` | Envoyer une invitation par e-mail |
| POST | `invites/accept/` | Accepter une invitation (token) |
| GET | `providers/catalog/` | Fournisseurs connus du pays du workspace |
| GET | `rates/` | Taux de change (`?base=XAF`), cache 12 h |
| GET | `meta/app-version/` | Dernière version publiée + URL de mise à jour |
| GET | `connectors/` | Connecteurs disponibles (métadonnées, pays, groupe) |
| POST | `connectors/<slug>/sync/` | Synchroniser un fournisseur (credentials → import) |
| GET | `connectors/powens/login/` | URL du webview bancaire (OAuth PSD2) |
| POST | `connectors/powens/callback/` | Échange du code → détection des prélèvements |
| GET | `connections/` | Comptes connectés (sans les secrets) |
| POST/DELETE | `connections/<id>/resync/` | Re-synchroniser / déconnecter un compte |

## Permissions par rôle

| Rôle | Droits |
|---|---|
| `owner` | Tout + gestion des utilisateurs |
| `manager` | CRUD abonnements, paiements |
| `assistant` | Voir + marquer payé |
| `viewer` | Lecture seule |

Appliquées côté serveur — le client ne fait que masquer les boutons.

## Connecteurs fournisseurs

`api/connectors/registry.py` enregistre des connecteurs découplés :

- **Cloud** : `ovh.py` (signature X-Ovh), `ionos.py`,
  `hetzner.py` (Hetzner + DigitalOcean), `cloud.py` (Vultr,
  UpCloud, Linode, Cloudflare)
- **Domaines** : `domains.py` (Gandi, GoDaddy, Namecheap)
- **Paiements récurrents** : `stripe.py`, `billing.py` (Mollie,
  Paddle, GoCardless)
- **Banque (OAuth)** : `powens.py` — agrégation PSD2

Chaque connecteur expose `fetch(credentials)` qui retourne les
abonnements détectés `{name, provider, category, amount, currency,
cycle, next_due_date}`. Les identifiants sont stockés chiffrés (Fernet,
`api/crypto.py`) — jamais en clair ni renvoyés au client.

### Connecteur Powens (agrégation bancaire)

Flux OAuth conforme PSD2 — Abonex ne voit jamais les identifiants
bancaires :

1. `GET /connectors/powens/login/` → `auth_url` du webview Powens
2. L'utilisateur se connecte à **sa banque** dans le webview ;
   redirection vers `abonex://powens/callback?code=…`
3. `POST /connectors/powens/callback/` échange le `code` contre un
   `access_token` (stocké chiffré) puis lit les transactions
4. `detect_recurring()` regroupe les débits par libellé : marchands
   revenant ≥ 2 fois à intervalle régulier → abonnement normalisé
   (cycle mensuel/trimestriel/annuel, montant médian, prochaine
   échéance, catégorie devinée : énergie, eau, télécom, loyer…)

Variables : `POWENS_CLIENT_ID`, `POWENS_CLIENT_SECRET`,
`POWENS_DOMAIN` (`sandbox.biapi.pro` en test, domaine client en prod)
— voir `DEPLOYMENT.md` §5.

Pour ajouter un fournisseur :

1. Créer `connectors/<nom>.py` avec `fetch()` + `auth_fields`
2. L'enregistrer dans `registry.py`
3. L'ajouter au catalogue `catalog.py` s'il est local à certains pays

Pour les fournisseurs sans API (eau, électricité locales…) : utiliser
l'import CSV ou la saisie guidée — le catalogue aide à pré-remplir.

## Taux de change

`GET /rates/?base=XAF` → `{ "XAF": 1, "USD": 0.0016, "EUR": 0.0015, … }`

- Source : API de taux en ligne (frankfurter.dev par défaut)
- Cache mémoire 12 h (`api/rates.py`)
- Conversion mobile : `amount / rates[currency]` vers la devise cible

## Déploiement

Voir **`../DEPLOYMENT.md`** — guide complet (Docker Compose,
PostgreSQL, nginx, HTTPS, Powens, checklist de mise en ligne).

- `config/settings.py` lit tout depuis l'environnement
- `Dockerfile` (gunicorn) + `docker-compose.yml` (db + backend + nginx)
- En DEBUG : `ALLOWED_HOSTS=*` ; en prod liste explicite
- Santé : `GET /health/` → `{"status": "ok"}`

## Tests

```bash
python manage.py test api
```
