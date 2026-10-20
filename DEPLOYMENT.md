# Déploiement Abonex — Production

Guide complet pour passer Abonex en production :
backend Django (Docker + PostgreSQL + nginx) et APK Android.

---

## 1. Architecture de production

```
Internet
   │  443/80
   ▼
nginx ──────────────┐           (reverse proxy, TLS, fichiers statiques)
   │                │
   ▼                │
gunicorn :8000      │           (3 workers, Django 5 / DRF)
   │                │
   ▼                │
PostgreSQL 17 ──────┘           (volume postgres_data)
```

Les trois services sont orchestrés par `backend/docker-compose.yml`.
Le healthcheck du backend interroge `GET /health/`.

## 2. Prérequis serveur

- VPS Linux (Ubuntu 22.04+ conseillé), 1 Go RAM minimum, 2 Go recommandé
- Docker + plugin Compose (`docker compose version`)
- Nom de domaine pointé vers l'IP du VPS (ex. `api.mondomaine.com`)

## 3. Déploiement backend

```bash
# Sur le serveur
git clone <repo> abonex && cd abonex/backend
cp .env.example .env
nano .env          # remplir TOUTES les valeurs (voir §4)

docker compose up -d --build
docker compose logs -f backend   # vérifier le démarrage

# Premier superuser (admin Django)
docker compose exec backend python manage.py createsuperuser
```

Vérification :

```bash
curl https://api.mondomaine.com/health/     # {"status":"ok"}
```

## 4. Variables d'environnement (`.env`)

| Variable | Obligatoire | Rôle |
|---|---|---|
| `DJANGO_DEBUG` | oui | `false` en production |
| `DJANGO_SECRET_KEY` | oui | `secrets.token_urlsafe(50)` |
| `DJANGO_ALLOWED_HOSTS` | oui | `api.mondomaine.com` (séparés par `,`) |
| `CORS_ALLOWED_ORIGINS` | web/desktop | origines autorisées (app mobile : pas nécessaire) |
| `CSRF_TRUSTED_ORIGINS` | admin web | `https://api.mondomaine.com` |
| `POSTGRES_DB/USER/PASSWORD` | oui | base PostgreSQL du compose |
| `PROVIDER_SECRET_KEY` | oui | clé Fernet dédiée (credentials + tokens Powens chiffrés) |
| `POWENS_CLIENT_ID` | agrégation | client_id de la console Powens |
| `POWENS_CLIENT_SECRET` | agrégation | client_secret Powens |
| `POWENS_DOMAIN` | agrégation | `sandbox.biapi.pro` (test) ou domaine prod Powens |
| `APP_LATEST_VERSION` | recommandé | dernière version publiée (ex. `1.0.0`) |
| `APP_UPDATE_URL` | recommandé | lien APK/Play Store du bouton « Mettre à jour » |
| `EMAIL_*` | optionnel | SMTP pour les invitations |
| `RATES_*` | optionnel | API Forex interne (sinon repli public) |

## 5. Powens en production (agrégation bancaire)

1. Compte professionnel sur <https://console.powens.com> → créer
   l'application « Abonex ».
2. Dans la console : enregistrer la redirection `abonex://powens/callback`.
3. Récupérer `client_id` / `client_secret` et le domaine API attribué
   (`sandbox.biapi.pro` pour les tests, domaine client dédié en prod).
4. Renseigner `.env` :

   ```env
   POWENS_CLIENT_ID=xxxxxxxx
   POWENS_CLIENT_SECRET=xxxxxxxx
   POWENS_DOMAIN=<votre-domaine>.biapi.pro   # pas "sandbox" en prod
   ```

5. Redémarrer : `docker compose up -d backend`.

> **Note conformité** : l'environnement de production Powens exige un
> accord PSD2 validé par Powens (contrat + validation de l'app). Le
> sandbox fonctionne immédiatement avec des banques de test.

Sans configuration Powens, le reste de l'application fonctionne
normalement — seule la carte « Synchronisation bancaire » renvoie
une erreur explicite à l'utilisateur.

## 6. HTTPS

`nginx/default.conf` écoute en 80 par défaut. Deux options :

- **Reverse proxy frontal** (Traefik, Caddy, Dokploy…) : terminer le
  TLS en amont, garder ce compose derrière — `X-Forwarded-Proto`
  est déjà propagé (`SECURE_PROXY_SSL_HEADER`).
- **Certbot + nginx** : ajouter un bloc `listen 443 ssl` dans
  `nginx/default.conf` avec les certificats Let's Encrypt.

Activer ensuite `DJANGO_SECURE_SSL_REDIRECT=true` et
`DJANGO_SECURE_HSTS_SECONDS=31536000` dans `.env`.

## 7. Application mobile (APK)

```bash
cd mobile
flutter build apk --release \
  --dart-define=API_BASE_URL=https://api.mondomaine.com/api/v1
```

- L'APK `app-release.apk` peut être hébergé sur le domaine et pointé
  par `APP_UPDATE_URL` (mise à jour in-app depuis le Profil).
- La CI `.github/workflows/apk.yml` construit l'APK à chaque push
  (URL : variable `API_BASE_URL` du workflow).
- Publication Play Store : build `appbundle`, signature release,
  puis remplacer `APP_UPDATE_URL` par le lien Play.

Deep-link bancaire : `abonex://powens/callback` (intent-filter
déjà déclaré dans `AndroidManifest.xml`).

## 8. Exploitation

| Opération | Commande |
|---|---|
| Logs | `docker compose logs -f backend` |
| Mise à jour code | `git pull && docker compose up -d --build` |
| Migrations | automatiques au démarrage (`entrypoint.sh`) |
| Sauvegarde DB | `docker compose exec db pg_dump -U abonex abonex > backup.sql` |
| Nouvelle version app | bump `version:` dans `mobile/pubspec.yaml`, rebuild APK, maj `APP_LATEST_VERSION` + `APP_UPDATE_URL` |

## 9. Checklist avant mise en ligne

- [ ] `DJANGO_DEBUG=false`, `DJANGO_SECRET_KEY` unique
- [ ] `PROVIDER_SECRET_KEY` défini (chiffrement tokens Powens)
- [ ] `DJANGO_ALLOWED_HOSTS` = domaine réel uniquement
- [ ] HTTPS actif + `DJANGO_SECURE_SSL_REDIRECT=true`
- [ ] `POSTGRES_PASSWORD` fort, `postgres_data` sauvegardé
- [ ] `POWENS_*` renseignés (domaine de production, pas sandbox)
- [ ] `APP_UPDATE_URL` pointe vers l'APK/Play Store réel
- [ ] `curl https://…/health/` → `{"status":"ok"}`
- [ ] APK construit avec `API_BASE_URL` en HTTPS
- [ ] Compte owner créé, parcours complet testé sur téléphone
