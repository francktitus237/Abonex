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

| Variable | Défaut | Rôle |
|---|---|---|
| `DJANGO_DEBUG` | `False` | Mode debug — en prod toujours `False` |
| `DJANGO_SECRET_KEY` | — | Clé secrète Django (obligatoire en prod) |
| `ALLOWED_HOSTS` | `*` en DEBUG | Hôtes autorisés, séparés par `,` |
| `FIELD_ENCRYPTION_KEY` | dérivée du SECRET_KEY | Clé Fernet pour les identifiants fournisseurs |
| `EMAIL_HOST`, `EMAIL_PORT`, `EMAIL_HOST_USER`, `EMAIL_HOST_PASSWORD` | console | SMTP pour les invitations par e-mail |
| `RATES_API_URL` | api.frankfurter.dev | Source des taux de change |

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
| GET/POST | `connectors/` | Connexions fournisseurs |
| POST | `connectors/<slug>/sync/` | Synchroniser un fournisseur |

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
`ovh.py` (signature X-Ovh), `ionos.py` (Bearer), `stripe.py`,
`hetzner.py`, `digitalocean.py`.

Chaque connecteur expose `sync(connection)` qui retourne les services
facturés du compte. Les identifiants sont stockés chiffrés (Fernet,
`api/crypto.py`) — jamais en clair. Pour ajouter un fournisseur :

1. Créer `connectors/<nom>.py` avec une classe `sync()`
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

- `config/settings.py` lit tout depuis l'environnement
- En DEBUG : `ALLOWED_HOSTS=*` ; en prod liste explicite
- Santé : `GET /health/` → `{"status": "ok"}`

## Tests

```bash
python manage.py test api
```
