# Abonex

**Gestion intelligente des dépenses récurrentes** pour les entreprises,
les indépendants et les foyers : abonnements, factures (eau, électricité,
télécom, internet), loyers, salaires, assurances, logiciels, événements
et rendez-vous.

Abonex centralise toutes vos obligations de paiement, calcule vos dépenses
mensuelles dans **votre devise locale**, vous alerte avant chaque échéance
avec des rappels personnalisables, et réduit la saisie manuelle grâce à
l'**import de fichiers** et aux **intégrations fournisseurs**.

- Backend : Django 5 + Django REST Framework (`backend/`)
- Mobile : Flutter (`mobile/`), Android 8.0+
- API : versionnée sous `/api/v1`

## Fonctionnalités

### Suivi et tableau de bord
- Montants du mois : dépensé, reste à payer, consommation budgétaire
- Échéances en retard et prochaines échéances
- Totaux affichés dans la **devise locale de l'utilisateur**
  (conversion par taux de change réels, aucun mélange de devises)
- Rapports : répartition par catégorie, prévisions à 6 mois

### Abonnements et agenda
- Cycles : mensuel, trimestriel, annuel, **paiement unique** (événements,
  rendez-vous)
- Saisie rétroactive : un abonnement pris dimanche saisi mercredi calcule
  automatiquement la prochaine échéance
- Date de début optionnelle ou inconnue, date de fin
- Catégories : logiciels, loyer, assurance, télécom, énergie, eau,
  salaires, transport, événement, autre

### Rappels personnalisables
- Plusieurs alertes avant l'échéance : J-14, J-7, J-3, J-1, J
- Heure de rappel configurable (par défaut 9h)
- Alerte plein écran avec sonnerie le jour J (type alarme)
- Notifications conservées après redémarrage du téléphone

### Multi-devises et international
- Choix du pays, langue, devise principale et devises secondaires
  au premier démarrage
- Suggestion automatique de la devise/langue selon le pays
- Taux de change en ligne via `GET /api/v1/rates/` (cache 12 h)
- Couverture : Afrique francophone/anglophone, UE, Amériques, Asie
- Interface en français et anglais (extensible via `intl`/ARB)

### Automatisation — moins de saisie manuelle
- **Import CSV** en masse (`/subscriptions/bulk/`) : nom, fournisseur,
  montant, devise, cycle, échéance
- **Agrégation bancaire (Powens / PSD2)** : connexion sécurisée à la
  banque via webview OAuth — les prélèvements récurrents (énergie,
  eau, télécom, loyer, streaming…) sont détectés automatiquement
  avec vraies dates et montants
- **Connecteurs fournisseurs** (framework extensible) : OVH, IONOS,
  Hetzner, DigitalOcean, Vultr, UpCloud, Linode, Cloudflare,
  Gandi, GoDaddy, Namecheap, Stripe, Mollie, Paddle, GoCardless —
  synchronisation des services en un clic depuis un compte client
- **Comptes connectés** : re-synchronisation en un tap, identifiants
  chiffrés (Fernet) jamais renvoyés au client
- **Catalogue par pays** (`/providers/catalog/`) : autocomplétion des
  fournisseurs locaux et internationaux (ENEO, EDF, Orange, MTN…)
- Identifiants fournisseurs chiffrés côté serveur (Fernet)

### Collaboration
- Espaces de travail partagés avec rôles : Propriétaire, Gestionnaire,
  Assistant, Lecteur
- Invitations par e-mail confirmées par l'invité (`/invites/accept/`)
- Permissions appliquées côté serveur (les contrôles Flutter ne font
  que masquer l'interface)

## Démarrage rapide

```bash
# Backend
cd backend
python -m venv .venv && .venv/Scripts/activate   # Windows
pip install -r requirements.txt
python manage.py migrate
python manage.py seed          # données de démonstration
python manage.py runserver 0.0.0.0:8000

# Mobile
cd mobile
flutter pub get
flutter pub run build_runner build --delete-conflicting-outputs
flutter run --dart-define=API_BASE_URL=http://<ip>:8000/api/v1
```

Compte de démonstration (seed) : `demo@abonex.app` — voir `backend/README.md`.

## Structure

```
Abonex/
├── backend/            API Django REST
│   ├── api/            modèles, vues, connecteurs, taux de change
│   └── config/         settings Django
├── mobile/             Application Flutter
│   ├── lib/core/       réseau, DI, router, stockage, notifications
│   └── lib/features/   auth, dashboard, abonnements, rapports, workspace…
└── .github/workflows/  CI : tests + build APK de production
```

## Documentation

- **`DEPLOYMENT.md`** — mise en production complète (Docker,
  PostgreSQL, nginx, HTTPS, Powens, checklist)
- `backend/README.md` — API, modèles, connecteurs, variables d'env
- `mobile/README.md` — architecture Flutter, build, réglages
- `.github/workflows/apk.yml` — build de l'APK en ligne
