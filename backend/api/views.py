import json
import os
import secrets
import uuid
from datetime import date, datetime, timedelta

from django.contrib.auth import authenticate
from django.contrib.auth.models import User
from django.contrib.auth.tokens import default_token_generator
from django.core.cache import cache
from django.core.mail import send_mail
from django.shortcuts import get_object_or_404
from django.utils import timezone
from django.utils.encoding import force_bytes, force_str
from django.utils.http import urlsafe_base64_decode, urlsafe_base64_encode
from rest_framework import generics, status
from rest_framework.parsers import FormParser, JSONParser, MultiPartParser
from rest_framework.permissions import AllowAny, IsAuthenticated
from rest_framework.response import Response
from rest_framework.views import APIView
from rest_framework_simplejwt.tokens import RefreshToken

from . import crypto
from .catalog import providers_for
from .connectors import CONNECTORS, connector_meta, get_connector
from .connectors.powens import (
    build_auth_url as powens_auth_url,
    exchange_code as powens_exchange_code,
    is_configured as powens_configured,
)
from .rates import rates_for
from .models import (
    Attachment, AuditLog, Budget, Comment, Department, Employee,
    Invitation, Membership, Payment, PayrollItem, Profile,
    ProviderConnection, Subscription, Supplier, Webhook,
    Workspace,
)
from .serializers import (
    AttachmentSerializer, BudgetSerializer, DepartmentSerializer,
    EmployeeSerializer, PayrollItemSerializer,
    PaymentSerializer, SubscriptionSerializer, SupplierSerializer,
    UserSerializer, WebhookSerializer,
    WorkspaceSerializer, WorkspaceBudgetSerializer,
)


from .permissions import (
    EmployeePermission, IsOwner, IsOwnerOrManager,
    SubscriptionPermission, has_cap,
)


class LoginView(APIView):
    """POST /auth/login/ {email, password} → {access, refresh, user}"""

    permission_classes = [AllowAny]
    throttle_scope = "login"  # anti force brute (voir REST_FRAMEWORK)

    def post(self, request):
        email = (request.data.get("email") or "").strip().lower()
        password = request.data.get("password") or ""
        try:
            user = User.objects.get(email=email)
        except User.DoesNotExist:
            user = None
        except User.MultipleObjectsReturned:
            user = User.objects.filter(email=email).first()
        if user is None:
            auth_user = None
        else:
            auth_user = authenticate(
                request, username=user.username, password=password
            )
        if auth_user is None:
            return Response(
                {"detail": "Identifiants incorrects."},
                status=status.HTTP_401_UNAUTHORIZED,
            )
        # 2FA : profil activé → on renvoie un pre-token signé à
        # 5 minutes ; le vrai JWT arrive après /auth/2fa/verify/.
        if auth_user.profile.totp_enabled:
            from django.core.signing import dumps

            return Response(
                {
                    "requires_2fa": True,
                    "pre_token": dumps(
                        {"uid": auth_user.pk}, salt="2fa"
                    ),
                }
            )
        refresh = RefreshToken.for_user(auth_user)
        return Response(
            {
                "access": str(refresh.access_token),
                "refresh": str(refresh),
                "user": UserSerializer(
                    auth_user, context={"request": request}
                ).data,
            }
        )


class TotpSetupView(APIView):
    """POST /auth/2fa/setup/ — génère le secret TOTP et renvoie
    l'URI otpauth:// pour l'app d'authentification (QR)."""

    def post(self, request):
        import pyotp

        profile = request.user.profile
        secret = pyotp.random_base32()
        profile.totp_secret = secret
        profile.save(update_fields=["totp_secret"])
        uri = pyotp.TOTP(secret).provisioning_uri(
            name=request.user.email, issuer_name="Abonex"
        )
        return Response({"uri": uri})


class TotpEnableView(APIView):
    """POST /auth/2fa/enable/ {code} — active la 2FA si le code
    généré par l'app correspond au secret provisoire."""

    def post(self, request):
        import pyotp

        profile = request.user.profile
        code = str(request.data.get("code") or "").strip()
        if not profile.totp_secret:
            return Response(status=status.HTTP_400_BAD_REQUEST)
        if not pyotp.TOTP(profile.totp_secret).verify(
            code, valid_window=1
        ):
            return Response(
                {"detail": "Code invalide."},
                status=status.HTTP_400_BAD_REQUEST,
            )
        profile.totp_enabled = True
        profile.save(update_fields=["totp_enabled"])
        return Response({"enabled": True})


class TotpDisableView(APIView):
    """POST /auth/2fa/disable/ {code} — désactive après
    vérification du code en cours."""

    def post(self, request):
        import pyotp

        profile = request.user.profile
        code = str(request.data.get("code") or "").strip()
        if not pyotp.TOTP(profile.totp_secret).verify(
            code, valid_window=1
        ):
            return Response(
                {"detail": "Code invalide."},
                status=status.HTTP_400_BAD_REQUEST,
            )
        profile.totp_enabled = False
        profile.totp_secret = ""
        profile.save(
            update_fields=["totp_enabled", "totp_secret"]
        )
        return Response({"enabled": False})


class TotpVerifyView(APIView):
    """POST /auth/2fa/verify/ {pre_token, code} — 2ᵉ étape du
    login : vérifie le code TOTP puis délivre les JWT."""

    permission_classes = [AllowAny]
    throttle_scope = "login"

    def post(self, request):
        import pyotp
        from django.core.signing import (
            BadSignature, SignatureExpired, loads,
        )

        pre = request.data.get("pre_token") or ""
        code = str(request.data.get("code") or "").strip()
        try:
            uid = loads(pre, salt="2fa", max_age=300)["uid"]
        except (BadSignature, SignatureExpired):
            return Response(
                {"detail": "Session expirée, reconnectez-vous."},
                status=status.HTTP_401_UNAUTHORIZED,
            )
        user = get_object_or_404(User, pk=uid)
        if not pyotp.TOTP(user.profile.totp_secret).verify(
            code, valid_window=1
        ):
            return Response(
                {"detail": "Code invalide."},
                status=status.HTTP_401_UNAUTHORIZED,
            )
        refresh = RefreshToken.for_user(user)
        return Response(
            {
                "access": str(refresh.access_token),
                "refresh": str(refresh),
                "user": UserSerializer(
                    user, context={"request": request}
                ).data,
            }
        )


# Pays → (devise principale, langue) pour la configuration
# automatique dès l'inscription — le setup finit ensuite
# (devises secondaires, invitations) via /workspace/setup/.
COUNTRY_DEFAULTS = {
    "CM": ("XAF", "fr"), "GA": ("XAF", "fr"), "CG": ("XAF", "fr"),
    "TD": ("XAF", "fr"), "GQ": ("XAF", "fr"),
    "CI": ("XOF", "fr"), "SN": ("XOF", "fr"), "BJ": ("XOF", "fr"),
    "BF": ("XOF", "fr"), "TG": ("XOF", "fr"), "ML": ("XOF", "fr"),
    "NE": ("XOF", "fr"), "GN": ("GNF", "fr"),
    "CD": ("CDF", "fr"), "MG": ("MGA", "fr"),
    "MA": ("MAD", "fr"), "DZ": ("DZD", "ar"), "TN": ("TND", "ar"),
    "NG": ("NGN", "en"), "GH": ("GHS", "en"), "KE": ("KES", "en"),
    "ZA": ("ZAR", "en"), "RW": ("RWF", "en"), "UG": ("UGX", "en"),
    "TZ": ("TZS", "en"), "ET": ("ETB", "en"),
    "FR": ("EUR", "fr"), "BE": ("EUR", "fr"), "LU": ("EUR", "fr"),
    "DE": ("EUR", "de"), "ES": ("EUR", "es"), "IT": ("EUR", "it"),
    "PT": ("EUR", "pt"), "NL": ("EUR", "nl"), "IE": ("EUR", "en"),
    "AT": ("EUR", "de"), "GR": ("EUR", "el"), "PL": ("PLN", "pl"),
    "RO": ("RON", "ro"), "SE": ("SEK", "sv"), "DK": ("DKK", "da"),
    "CH": ("CHF", "fr"), "GB": ("GBP", "en"),
    "US": ("USD", "en"), "CA": ("CAD", "en"), "MX": ("MXN", "es"),
    "BR": ("BRL", "pt"), "AR": ("ARS", "es"), "CO": ("COP", "es"),
    "CL": ("CLP", "es"), "HT": ("HTG", "fr"),
    "IN": ("INR", "en"), "ID": ("IDR", "id"), "PH": ("PHP", "en"),
    "VN": ("VND", "vi"), "TH": ("THB", "th"), "SG": ("SGD", "en"),
    "PK": ("PKR", "ur"), "BD": ("BDT", "bn"),
    "AE": ("AED", "ar"), "SA": ("SAR", "ar"), "TR": ("TRY", "tr"),
    "JP": ("JPY", "ja"), "CN": ("CNY", "zh"), "KR": ("KRW", "ko"),
}


class RegisterView(APIView):
    """POST /auth/register/ → crée le compte + profil, renvoie
    {access, refresh, user} comme /auth/login/."""

    permission_classes = [AllowAny]

    def post(self, request):
        email = (request.data.get("email") or "").strip().lower()
        password = request.data.get("password") or ""
        first_name = (request.data.get("first_name") or "").strip()
        last_name = (request.data.get("last_name") or "").strip()
        country = (request.data.get("country") or "").strip().upper()

        errors = {}
        if "@" not in email:
            errors["email"] = "Email invalide."
        if len(password) < 8:
            errors["password"] = "8 caractères minimum."
        if not errors and User.objects.filter(email=email).exists():
            errors["email"] = "Un compte existe déjà pour cet email."
        if errors:
            return Response(errors, status=status.HTTP_400_BAD_REQUEST)

        user = User.objects.create_user(
            username=email,
            email=email,
            password=password,
            first_name=first_name,
            last_name=last_name,
        )
        # Pays choisi à l'inscription → devise/langue configurées
        # automatiquement : pas d'écran de setup supplémentaire,
        # l'espace est prêt à l'emploi dès le premier login.
        currency, language = COUNTRY_DEFAULTS.get(country, ("", "fr"))
        kind = "business" if request.data.get("kind") == "business" else "personal"
        # L'inscrit est propriétaire de son propre espace de travail.
        workspace = Workspace.objects.create(
            name=f"Espace de {first_name or email}",
            kind=kind,
            country=country if country in COUNTRY_DEFAULTS else "",
            default_currency=currency,
            configured=True,
        )
        Profile.objects.create(
            user=user, workspace=workspace, role="owner",
            language=language,
        )
        # Registre multi-espaces : l'espace créé devient le premier
        # membership du compte (étude §4.2).
        Membership.objects.create(
            user=user, workspace=workspace, role="owner"
        )

        refresh = RefreshToken.for_user(user)
        return Response(
            {
                "access": str(refresh.access_token),
                "refresh": str(refresh),
                "user": UserSerializer(
                    user, context={"request": request}
                ).data,
            },
            status=status.HTTP_201_CREATED,
        )


class MeView(APIView):
    """GET /auth/me/ → user · PATCH → met à jour prénom, nom,
    email, langue et photo de profil (multipart pour l'avatar)."""

    parser_classes = [MultiPartParser, FormParser, JSONParser]

    def _serialize(self, request):
        # Le contexte request sert à construire l'URL absolue
        # de l'avatar (build_absolute_uri).
        return Response(
            UserSerializer(request.user, context={"request": request}).data
        )

    def get(self, request):
        return self._serialize(request)

    def delete(self, request):
        """DELETE /auth/me/ {password} — suppression définitive
        du compte (RGPD). Le mot de passe confirme l'action."""
        password = request.data.get("password") or ""
        if not request.user.check_password(password):
            return Response(
                {"password": "Mot de passe incorrect."},
                status=status.HTTP_400_BAD_REQUEST,
            )
        request.user.delete()
        return Response(status=status.HTTP_204_NO_CONTENT)

    def patch(self, request):
        user = request.user
        data = request.data
        errors = {}

        for field in ("first_name", "last_name"):
            if field in data:
                setattr(user, field, str(data[field]).strip()[:150])

        email = data.get("email")
        if email is not None:
            email = str(email).strip().lower()
            if "@" not in email:
                errors["email"] = "Email invalide."
            elif (
                User.objects.exclude(pk=user.pk)
                .filter(email=email)
                .exists()
            ):
                errors["email"] = "Un compte existe déjà pour cet email."
            else:
                # username == email dans ce projet : les deux bougent
                # ensemble pour conserver l'authentification par email.
                user.email = email
                user.username = email

        # Validation de l'avatar AVANT toute écriture : un fichier
        # refusé ne doit pas laisser les autres champs à moitié
        # enregistrés alors que la réponse est un 400.
        avatar_file = request.FILES.get("avatar")
        if avatar_file is not None:
            if not (avatar_file.content_type or "").startswith("image/"):
                errors["avatar"] = "Le fichier doit être une image."
            elif avatar_file.size > 5 * 1024 * 1024:
                errors["avatar"] = "Image trop lourde (5 Mo max)."

        if errors:
            return Response(errors, status=status.HTTP_400_BAD_REQUEST)
        user.save()

        profile = user.profile
        language = data.get("language")
        if language is not None:
            profile.language = str(language).strip()[:8]

        # Photo : fichier multipart OU chaîne vide pour la retirer.
        if avatar_file is not None:
            if profile.avatar:
                # L'ancien fichier serait sinon orphelin sur le disque.
                profile.avatar.delete(save=False)
            profile.avatar = avatar_file
        elif data.get("avatar") == "":
            profile.avatar.delete(save=False)
            profile.avatar = ""
        profile.save()

        return self._serialize(request)


class ChangePasswordView(APIView):
    """POST /auth/password/change/ {current_password, new_password}
    → 204. Les JWT existants restent valides (pas de révocation)."""

    throttle_scope = "password"

    def post(self, request):
        user = request.user
        current = request.data.get("current_password") or ""
        new = request.data.get("new_password") or ""
        if not user.check_password(current):
            return Response(
                {"current_password": "Mot de passe actuel incorrect."},
                status=status.HTTP_400_BAD_REQUEST,
            )
        if len(new) < 8:
            return Response(
                {"new_password": "8 caractères minimum."},
                status=status.HTTP_400_BAD_REQUEST,
            )
        user.set_password(new)
        user.save(update_fields=["password"])
        return Response(status=status.HTTP_204_NO_CONTENT)


class LogoutView(APIView):
    """POST /auth/logout/ {refresh} → blacklist du refresh token."""

    permission_classes = [AllowAny]

    def post(self, request):
        token = request.data.get("refresh")
        if token:
            try:
                RefreshToken(token).blacklist()
            except Exception:
                pass
        return Response(status=status.HTTP_204_NO_CONTENT)


class ForgotPasswordView(APIView):
    """POST /auth/password/forgot/ {email} → envoie un lien de
    réinitialisation (deep link `abonex://reset/<uid>/<token>`).
    Retourne toujours 204 — anti-énumération des comptes."""

    permission_classes = [AllowAny]
    throttle_scope = "password"

    def post(self, request):
        email = (request.data.get("email") or "").strip().lower()
        if email:
            # filter() et non get() : l'unicité de l'email est
            # applicative, pas une contrainte SQL — plusieurs lignes
            # ne doivent pas lever de 500.
            for user in User.objects.filter(email=email, is_active=True):
                uid = urlsafe_base64_encode(force_bytes(user.pk))
                token = default_token_generator.make_token(user)
                link = f"abonex://reset/{uid}/{token}"
                send_mail(
                    "Abonex — Réinitialisation du mot de passe",
                    (
                        "Bonjour,\n\n"
                        "Une demande de réinitialisation de mot de passe "
                        "a été faite pour votre compte Abonex.\n\n"
                        "Ouvrez ce lien dans l'application pour choisir "
                        "un nouveau mot de passe :\n"
                        f"{link}\n\n"
                        "Si vous n'êtes pas à l'origine de cette "
                        "demande, ignorez simplement cet email — "
                        "votre mot de passe reste inchangé.\n\n"
                        "— L'équipe Abonex"
                    ),
                    None,
                    [user.email],
                    fail_silently=True,
                )
        return Response(status=status.HTTP_204_NO_CONTENT)


class ResetPasswordView(APIView):
    """POST /auth/password/reset/ {uid, token, password} → 204.
    Le token est celui du lien envoyé par /auth/password/forgot/ —
    à usage unique : changer le mot de passe l'invalide."""

    permission_classes = [AllowAny]
    throttle_scope = "password"

    def post(self, request):
        uid = request.data.get("uid") or ""
        token = request.data.get("token") or ""
        password = request.data.get("password") or ""
        errors = {}
        user = None
        try:
            # urlsafe_base64_decode renvoie des bytes — force_str
            # obligatoire avant le lookup pk.
            user = User.objects.get(
                pk=force_str(urlsafe_base64_decode(uid))
            )
        except (TypeError, ValueError, OverflowError, User.DoesNotExist):
            user = None
        if user is None or not default_token_generator.check_token(
            user, token
        ):
            errors["token"] = "Lien invalide ou expiré."
        if len(password) < 8:
            errors["password"] = "8 caractères minimum."
        if errors:
            return Response(errors, status=status.HTTP_400_BAD_REQUEST)
        user.set_password(password)
        user.save(update_fields=["password"])
        # Sécurité : toutes les sessions existantes sont invalidées —
        # le reset peut suivre un compromission du compte.
        from rest_framework_simplejwt.token_blacklist.models import (
            BlacklistedToken, OutstandingToken,
        )
        for outstanding in OutstandingToken.objects.filter(user=user):
            BlacklistedToken.objects.get_or_create(token=outstanding)
        return Response(status=status.HTTP_204_NO_CONTENT)


def _send_verify_email(user):
    uid = urlsafe_base64_encode(force_bytes(user.pk))
    link = f"abonex://verify/{uid}/{default_token_generator.make_token(user)}"
    send_mail(
        "Abonex — Confirmez votre adresse email",
        f"Bonjour,\n\nConfirmez votre adresse en ouvrant ce lien "
        f"dans l'application :\n{link}\n\n— L'équipe Abonex",
        None,
        [user.email],
        fail_silently=True,
    )


class VerifyEmailView(APIView):
    """GET /auth/verify/<uid>/<token> — confirme l'adresse email.
    Même générateur de tokens que le reset de mot de passe."""

    permission_classes = [AllowAny]

    def get(self, request, uid, token):
        try:
            user = User.objects.get(
                pk=force_str(urlsafe_base64_decode(uid))
            )
        except (TypeError, ValueError, OverflowError, User.DoesNotExist):
            user = None
        if user is None or not default_token_generator.check_token(
            user, token
        ):
            return Response(
                {"token": "Lien invalide ou expiré."},
                status=status.HTTP_400_BAD_REQUEST,
            )
        profile = getattr(user, "profile", None)
        if profile is not None:
            profile.email_verified = True
            profile.save(update_fields=["email_verified"])
        return Response(status=status.HTTP_204_NO_CONTENT)


class ResendVerifyEmailView(APIView):
    """POST /auth/verify/resend/ — renvoie le lien de vérification
    (appelé aussi juste après l'inscription)."""

    def post(self, request):
        profile = getattr(request.user, "profile", None)
        if profile is None or profile.email_verified:
            return Response(status=status.HTTP_204_NO_CONTENT)
        _send_verify_email(request.user)
        return Response(status=status.HTTP_204_NO_CONTENT)


class DeviceTokenView(APIView):
    """POST /devices/ {token} — enregistre le jeton FCM de
    l'appareil pour les notifications push serveur."""

    def post(self, request):
        token = (request.data.get("token") or "").strip()[:255]
        profile = getattr(request.user, "profile", None)
        if token and profile is not None:
            profile.fcm_token = token
            profile.save(update_fields=["fcm_token"])
        return Response(status=status.HTTP_204_NO_CONTENT)


def _employee_next_due(pay_day):
    """Prochaine date de paie : le pay_day du mois courant s'il
    n'est pas passé, sinon celui du mois suivant (jour clampé
    sur les mois courts, ex. 31 → 28/29/30)."""
    today = date.today()
    day = min(max(1, int(pay_day)), _month_days(today.year, today.month))
    d = date(today.year, today.month, day)
    if d <= today:
        month = today.month + 1
        year = today.year + (month - 1) // 12
        month = (month - 1) % 12 + 1
        d = date(year, month, min(day, _month_days(year, month)))
    return d


def _sync_employee_subscription(employee, user):
    """(Ré)génère l'abonnement payroll de l'employé. Inactif →
    l'échéance disparaît du suivi (l'employé est conservé)."""
    sub = employee.subscription
    if not employee.active:
        if sub is not None:
            sub.delete()
            employee.subscription = None
            employee.save(update_fields=["subscription"])
        return
    due = _employee_next_due(employee.pay_day)
    if sub is not None:
        sub.name = f"Paie — {employee.name}"
        sub.amount = employee.salary
        sub.currency = employee.currency
        sub.description = employee.position
        sub.next_due_date = due
        sub.save(
            update_fields=[
                "name", "amount", "currency", "description",
                "next_due_date",
            ]
        )
    else:
        employee.subscription = Subscription.objects.create(
            owner=user,
            workspace=employee.workspace,
            name=f"Paie — {employee.name}",
            category="payroll",
            amount=employee.salary,
            currency=employee.currency,
            description=employee.position,
            next_due_date=due,
            cycle="monthly",
            status="dueSoon",
        )
        employee.save(update_fields=["subscription"])


class EmployeeListCreateView(APIView):
    """GET liste des employés de l'espace · POST crée un employé
    (owner/manager via SubscriptionPermission) + sa paie payroll."""

    permission_classes = [EmployeePermission]

    def get(self, request):
        ws = request.user.profile.workspace
        data = EmployeeSerializer(ws.employees.all(), many=True).data
        # Salaire masqué pour le manager (lecture RH sans montant) —
        # seul le propriétaire voit les salaires (étude §4.1).
        if request.user.profile.role != "owner":
            for e in data:
                e["salary"] = None
        return Response(data)

    def post(self, request):
        ws = request.user.profile.workspace
        ser = EmployeeSerializer(data=request.data)
        ser.is_valid(raise_exception=True)
        employee = ser.save(workspace=ws)
        _sync_employee_subscription(employee, request.user)
        return Response(
            EmployeeSerializer(employee).data,
            status=status.HTTP_201_CREATED,
        )


class EmployeeDetailView(APIView):
    """GET/PATCH un employé · DELETE retire l'employé ET son
    échéance payroll (l'historique de paiements part avec —
    comportement identique à la suppression d'abonnement)."""

    permission_classes = [EmployeePermission]

    def _employee(self, request, pk):
        return get_object_or_404(
            Employee, pk=pk, workspace=request.user.profile.workspace
        )

    def get(self, request, pk):
        return Response(
            EmployeeSerializer(self._employee(request, pk)).data
        )

    def patch(self, request, pk):
        employee = self._employee(request, pk)
        ser = EmployeeSerializer(employee, data=request.data, partial=True)
        ser.is_valid(raise_exception=True)
        ser.save()
        _sync_employee_subscription(employee, request.user)
        return Response(EmployeeSerializer(employee).data)

    def delete(self, request, pk):
        employee = self._employee(request, pk)
        if employee.subscription_id:
            employee.subscription.delete()
        employee.delete()
        return Response(status=status.HTTP_204_NO_CONTENT)


# ---- Intelligence : coût mensuel équivalent par cycle ----
_MONTHLY_FACTOR = {
    "monthly": 1.0,
    "quarterly": 1 / 3,
    "yearly": 1 / 12,
    "weekly": 52 / 12,
    "daily": 365 / 12,
    "once": 0.0,
}


class InsightsView(APIView):
    """GET /insights/ — recommandations intelligentes :
    doublons, alternatives moins chères (catalogue plans),
    total mensuel équivalent, reste à vivre vs budget."""

    def get(self, request):
        profile = request.user.profile
        ws = profile.workspace
        base = ws.default_currency or "XAF"
        subs = list(
            _visible_subscriptions(request).exclude(
                category="event"
            )
        )
        try:
            rates = rates_for(base) or {}
        except Exception:
            rates = {}

        def to_base(amount, currency):
            if currency == base:
                return amount
            rate = rates.get(currency)
            return amount / rate if rate else None

        def monthly_equiv(s):
            factor = _MONTHLY_FACTOR.get(s.cycle, 1.0)
            return float(s.amount) * factor

        # ---------- Dépense mensuelle équivalente (base) ----------
        monthly_total = 0.0
        for s in subs:
            conv = to_base(monthly_equiv(s), s.currency)
            if conv is not None:
                monthly_total += conv

        # ---------- Doublons : même fournisseur (ou nom) -------
        from collections import defaultdict

        by_name = defaultdict(list)
        for s in subs:
            key = (s.provider or s.name).strip().lower()
            if key:
                by_name[key].append(s)
        duplicates = [
            {
                "name": g[0].provider or g[0].name,
                "count": len(g),
                "monthly_total": round(
                    sum(monthly_equiv(s) for s in g), 2
                ),
                "currency": g[0].currency,
            }
            for g in by_name.values()
            if len(g) > 1
        ]

        # ---------- Alternatives moins chères (catalogue) -----
        from .catalog import CATALOG

        plans_by_provider = {}
        for p in CATALOG:
            name = p["name"].lower()
            for plan in p.get("plans") or []:
                factor = _MONTHLY_FACTOR.get(plan.get("cycle"), 1.0)
                plans_by_provider.setdefault(name, []).append(
                    {
                        "provider": p["name"],
                        "label": plan["label"],
                        "monthly": plan["amount"] * factor,
                        "currency": plan["currency"],
                    }
                )
        cheaper = []
        for s in subs:
            key = (s.provider or "").strip().lower() or s.name.strip().lower()
            plans = plans_by_provider.get(key)
            if not plans:
                continue
            current = monthly_equiv(s)
            same_ccy = [p for p in plans if p["currency"] == s.currency]
            best = min(same_ccy, key=lambda p: p["monthly"], default=None)
            # Économie significative : > 5 % et > 0.5 unité/mois.
            if best and best["monthly"] < current * 0.95 and (
                current - best["monthly"]
            ) > 0.5:
                cheaper.append(
                    {
                        "subscription": s.name,
                        "current_monthly": round(current, 2),
                        "suggestion": f"{best['provider']} {best['label']}",
                        "suggested_monthly": round(best["monthly"], 2),
                        "saving_monthly": round(
                            current - best["monthly"], 2
                        ),
                        "currency": s.currency,
                    }
                )
        cheaper.sort(key=lambda c: c["saving_monthly"], reverse=True)

        # ---------- Reste à vivre ----------
        rest = None
        if ws.monthly_budget is not None:
            rest = round(float(ws.monthly_budget) - monthly_total, 2)

        # ---------- Budgets par poste (catégorie/département) --
        # Usage = dépense mensuelle équivalente du périmètre
        # convertie en base, comparée au budget : alertes au
        # seuil configuré (80 % défaut) et au dépassement.
        budgets_usage = []
        for b in Budget.objects.filter(
            workspace=ws
        ).select_related("department"):
            spent = 0.0
            missing = False
            for s in subs:
                if b.department_id:
                    if s.department_id != b.department_id:
                        continue
                elif s.category != b.category:
                    continue
                conv = to_base(monthly_equiv(s), s.currency)
                if conv is None:
                    missing = True
                    continue
                spent += conv
            usage = (
                round(spent / float(b.amount) * 100, 1)
                if b.amount
                else 0.0
            )
            budgets_usage.append(
                {
                    "id": b.id,
                    "label": (
                        b.department.name
                        if b.department_id
                        else b.category
                    ),
                    "scope": (
                        "department" if b.department_id
                        else "category"
                    ),
                    "budget": float(b.amount),
                    "spent": round(spent, 2),
                    "usage_percent": usage,
                    "alert_threshold": b.alert_threshold,
                    "status": (
                        "over" if usage >= 100
                        else "warning"
                        if usage >= b.alert_threshold
                        else "ok"
                    ),
                    "conversion_missing": missing,
                }
            )

        return Response(
            {
                "monthly_total": round(monthly_total, 2),
                "base_currency": base,
                "monthly_budget": ws.monthly_budget,
                "reste_a_vivre": rest,
                "duplicates": duplicates,
                "cheaper_alternatives": cheaper,
                "potential_monthly_saving": round(
                    sum(c["saving_monthly"] for c in cheaper), 2
                ),
                "budgets": budgets_usage,
            }
        )


class ExportCsvView(APIView):
    """GET /export/csv/ — export RGPD + comptabilité : toutes les
    données de l'espace courant en CSV (abonnements + paiements)."""

    def get(self, request):
        import csv
        import io

        ws = request.user.profile.workspace
        buf = io.StringIO()
        w = csv.writer(buf)
        w.writerow(
            [
                "type", "id", "name", "provider", "category", "cycle",
                "amount", "currency", "status", "due_date", "due_time",
                "paid_at", "country", "description",
            ]
        )
        for s in _visible_subscriptions(request):
            w.writerow(
                [
                    "subscription", s.pk, s.name, s.provider, s.category,
                    s.cycle, s.amount, s.currency, s.status,
                    s.next_due_date, s.due_time or "", "", s.country,
                    s.description,
                ]
            )
        for p in Payment.objects.filter(
            workspace=ws
        ).select_related("subscription", "recorded_by"):
            w.writerow(  # noqa: E501
                [
                    "payment", p.pk, p.subscription.name, "", "", "",
                    p.amount, p.subscription.currency, "paid", p.due_date,
                    "", p.paid_at, "", "",
                ]
            )
        from django.http import HttpResponse

        resp = HttpResponse(
            buf.getvalue(), content_type="text/csv; charset=utf-8"
        )
        resp["Content-Disposition"] = (
            'attachment; filename="abonex_export.csv"'
        )
        return resp


class ExportXlsxView(APIView):
    """GET /export/xlsx/ — journal comptable Excel (étude §F) :
    feuille Paiements (montant prévu/réel, mode, référence,
    statut, déclaré par) + feuille Échéances."""

    def get(self, request):
        from openpyxl import Workbook
        from openpyxl.styles import Font, PatternFill

        ws = request.user.profile.workspace
        wb = Workbook()
        head_fill = PatternFill("solid", fgColor="1E3A8A")
        head_font = Font(bold=True, color="FFFFFF")

        # --- Journal des paiements ---
        pay = wb.active
        pay.title = "Journal des paiements"
        headers = [
            "Date", "Échéance", "Montant prévu", "Montant payé",
            "Devise", "Mode", "Référence", "Statut", "Déclaré par",
            "Échéance du",
        ]
        pay.append(headers)
        for cell in pay[1]:
            cell.fill = head_fill
            cell.font = head_font
        for p in (
            Payment.objects.filter(workspace=ws)
            .select_related("subscription", "recorded_by")
            .order_by("-due_date")
        ):
            pay.append([
                p.paid_at.strftime("%Y-%m-%d") if p.paid_at else "",
                p.subscription.name,
                float(p.amount),
                float(p.amount_paid) if p.amount_paid is not None
                else float(p.amount),
                p.subscription.currency,
                p.method or "",
                p.reference or "",
                p.status,
                p.recorded_by.get_full_name() or p.recorded_by.email
                if p.recorded_by else "",
                str(p.due_date),
            ])
        for col, width in zip("ABCDEFGHIJ", (12, 28, 14, 14, 8, 14, 18, 10, 22, 14)):
            pay.column_dimensions[col].width = width

        # --- Échéances actives ---
        sub = wb.create_sheet("Échéances")
        sub.append([
            "Nom", "Fournisseur", "Catégorie", "Montant", "Devise",
            "Cycle", "Statut", "Prochaine échéance", "Département",
        ])
        for cell in sub[1]:
            cell.fill = head_fill
            cell.font = head_font
        for s in _visible_subscriptions(request).select_related(
            "department"
        ):
            sub.append([
                s.name, s.provider or "", s.category,
                float(s.amount), s.currency, s.cycle, s.status,
                str(s.next_due_date),
                s.department.name if s.department else "",
            ])
        for col, width in zip("ABCDEFGHI", (28, 18, 12, 12, 8, 10, 10, 18, 16)):
            sub.column_dimensions[col].width = width

        from django.http import HttpResponse
        import io as _io

        buf = _io.BytesIO()
        wb.save(buf)
        resp = HttpResponse(
            buf.getvalue(),
            content_type=(
                "application/vnd.openxmlformats-officedocument."
                "spreadsheetml.sheet"
            ),
        )
        resp["Content-Disposition"] = (
            'attachment; filename="abonex_journal.xlsx"'
        )
        return resp


def _monthly_pdf(ws, subscriptions):
    """Génère le PDF du rapport mensuel (étude §F) — partagé par
    l'export GET /export/pdf/ ET la commande d'envoi automatique
    `send_monthly_reports` (cron). Retourne les octets du PDF."""
    from reportlab.lib.pagesizes import A4
    from reportlab.lib.units import mm
    from reportlab.pdfgen import canvas
    import io as _io

    base = ws.default_currency or "XAF"
    subs = list(subscriptions.exclude(category="event"))
    try:
        rates = rates_for(base) or {}
    except Exception:
        rates = {}

    def to_base(amount, currency):
        if currency == base:
            return float(amount)
        rate = rates.get(currency)
        return float(amount) / rate if rate else None

    from collections import defaultdict

    by_cat = defaultdict(float)
    total = 0.0
    for s in subs:
        factor = _MONTHLY_FACTOR.get(s.cycle, 1.0)
        conv = to_base(float(s.amount) * factor, s.currency)
        if conv is None:
            continue
        total += conv
        by_cat[s.category] += conv
    overdue = sum(
        1 for s in subs if s.status == "overdue"
    )
    pending = Payment.objects.filter(
        workspace=ws, status="pending"
    ).count()

    buf = _io.BytesIO()
    pdf = canvas.Canvas(buf, pagesize=A4)
    width, height = A4
    y = height - 20 * mm
    pdf.setFont("Helvetica-Bold", 18)
    pdf.drawString(
        20 * mm, y, ws.legal_name or ws.name
    )
    y -= 7 * mm
    pdf.setFont("Helvetica", 10)
    pdf.drawString(
        20 * mm,
        y,
        f"Rapport de charges — {timezone.localdate():%d/%m/%Y}",
    )
    if ws.tax_id:
        y -= 5 * mm
        pdf.drawString(20 * mm, y, f"N° fiscal : {ws.tax_id}")
    if ws.sector:
        y -= 5 * mm
        pdf.drawString(20 * mm, y, f"Secteur : {ws.sector}")
    y -= 12 * mm
    pdf.setFont("Helvetica-Bold", 13)
    pdf.drawString(
        20 * mm, y, f"Charges mensuelles : {total:,.2f} {base}"
    )
    y -= 7 * mm
    pdf.setFont("Helvetica", 10)
    if ws.monthly_budget is not None:
        rest = float(ws.monthly_budget) - total
        pdf.drawString(
            20 * mm,
            y,
            f"Budget : {float(ws.monthly_budget):,.2f} {base} · "
            f"Marge : {rest:,.2f} {base}",
        )
        y -= 6 * mm
    pdf.drawString(
        20 * mm,
        y,
        f"{len(subs)} échéances actives · {overdue} en retard"
        f" · {pending} à valider",
    )
    y -= 12 * mm
    pdf.setFont("Helvetica-Bold", 12)
    pdf.drawString(20 * mm, y, "Répartition par catégorie")
    y -= 7 * mm
    pdf.setFont("Helvetica", 10)
    for cat, amount in sorted(
        by_cat.items(), key=lambda kv: -kv[1]
    ):
        if y < 25 * mm:
            pdf.showPage()
            y = height - 20 * mm
            pdf.setFont("Helvetica", 10)
        pct = amount / total * 100 if total else 0
        pdf.drawString(
            25 * mm,
            y,
            f"{cat} : {amount:,.2f} {base} ({pct:.0f} %)",
        )
        y -= 6 * mm
    pdf.showPage()
    pdf.save()
    return buf.getvalue()


class ExportPdfView(APIView):
    """GET /export/pdf/ — rapport mensuel pro (étude §F)."""

    def get(self, request):
        ws = request.user.profile.workspace
        pdf_bytes = _monthly_pdf(
            ws, _visible_subscriptions(request)
        )
        from django.http import HttpResponse

        resp = HttpResponse(
            pdf_bytes, content_type="application/pdf"
        )
        resp["Content-Disposition"] = (
            'attachment; filename="abonex_rapport.pdf"'
        )
        return resp


class UserListView(generics.ListAPIView):
    """GET /users/ — réservé au Propriétaire."""

    serializer_class = UserSerializer
    permission_classes = [IsOwner]

    def get_queryset(self):
        return User.objects.select_related("profile").filter(
            profile__workspace=self.request.user.profile.workspace
        ).order_by("id")


class UserDetailView(generics.RetrieveUpdateDestroyAPIView):
    serializer_class = UserSerializer
    permission_classes = [IsOwner]

    def get_queryset(self):
        return User.objects.select_related("profile").filter(
            profile__workspace=self.request.user.profile.workspace
        )

    def update(self, request, *args, **kwargs):
        target = self.get_object()
        role = request.data.get("role")
        if target == request.user:
            return Response(
                {"role": ["Vous ne pouvez pas modifier votre propre rôle."]},
                status=status.HTTP_400_BAD_REQUEST,
            )
        if role not in {"manager", "assistant", "viewer"}:
            return Response(
                {"role": ["Rôle non autorisé."]},
                status=status.HTTP_400_BAD_REQUEST,
            )
        _audit(
            request,
            "role_change",
            "member",
            target.email,
            before={"role": target.profile.role},
            after={"role": role},
        )
        return super().update(request, *args, **kwargs)

    def destroy(self, request, *args, **kwargs):
        """DELETE /users/<id>/ — retire un membre de l'espace
        (étude §4.3). Le profil est supprimé → le compte devient
        orphelin jusqu'à une nouvelle invitation ; on ne supprime
        JAMAIS le propriétaire ni soi-même."""
        target = self.get_object()
        if target == request.user:
            return Response(
                {"detail": ["Impossible de se retirer soi-même."]},
                status=status.HTTP_400_BAD_REQUEST,
            )
        if target.profile.role == "owner":
            return Response(
                {"detail": ["Impossible de retirer le propriétaire."]},
                status=status.HTTP_400_BAD_REQUEST,
            )
        email = target.email
        role = target.profile.role
        ws = request.user.profile.workspace
        # Membership : on révoque l'accès à CET espace plutôt que
        # de détruire le profil — le compte garde ses autres
        # espaces (§4.2) ; s'il n'en a plus, l'espace actif est
        # recréé en espace personnel neuf.
        Membership.objects.filter(
            user=target, workspace=ws
        ).delete()
        if target.profile.workspace_id == ws.id:
            fallback = (
                Membership.objects.filter(
                    user=target, status="active"
                )
                .select_related("workspace")
                .first()
            )
            if fallback is not None:
                target.profile.workspace = fallback.workspace
                target.profile.role = fallback.role
                target.profile.save(
                    update_fields=["workspace", "role"]
                )
            else:
                personal = Workspace.objects.create(
                    name=f"Espace de {target.first_name or email}",
                    kind="personal",
                )
                Membership.objects.create(
                    user=target, workspace=personal, role="owner"
                )
                target.profile.workspace = personal
                target.profile.role = "owner"
                target.profile.save(
                    update_fields=["workspace", "role"]
                )
        _audit(
            request,
            "member_remove",
            "member",
            email,
            before={"role": role},
        )
        return Response(status=status.HTTP_204_NO_CONTENT)


def _refresh_statuses(qs):
    """Recalcule les statuts selon la date du jour :
    dueSoon dont l'échéance est passée → overdue ;
    paid RÉCURRENT dont la date est dépassée (nouvelle période) →
    overdue. Un événement 'once' payé est TERMINAL : sa date reste
    dans le passé mais il ne doit jamais redevenir en retard."""
    today = date.today()
    qs.filter(
        status__in=["dueSoon", "paid"], next_due_date__lt=today
    ).exclude(status="paid", cycle="once").update(status="overdue")


def _advance_due(subscription):
    """Après un paiement : fait avancer next_due_date d'un cycle
    complet jusqu'à une date future, puis repasse en dueSoon.
    Un événement 'once' payé reste payé (terminal)."""
    from datetime import date as _date

    if subscription.cycle == "once":
        return
    today = _date.today()
    d = subscription.next_due_date
    # Récurrences en jours : la date avance d'un pas fixe —
    # même heure, même jour de semaine pour l'hebdo.
    if subscription.cycle in ("daily", "weekly"):
        from datetime import timedelta

        step_days = 1 if subscription.cycle == "daily" else 7
        guard = 0
        while d <= today and guard < 800:
            d = d + timedelta(days=step_days)
            guard += 1
        if subscription.end_date and d > subscription.end_date:
            subscription.status = "paid"
            subscription.save(update_fields=["status"])
            return
        subscription.next_due_date = d
        subscription.status = "dueSoon"
        subscription.save(update_fields=["next_due_date", "status"])
        return
    step = {"monthly": 1, "quarterly": 3, "yearly": 12}.get(
        subscription.cycle, 1
    )
    guard = 0
    while d <= today and guard < 240:
        month = d.month - 1 + step
        year = d.year + month // 12
        month = month % 12 + 1
        # Dernier jour du mois si le jour n'existe pas (31 février…).
        day = min(d.day, _month_days(year, month))
        d = _date(year, month, day)
        guard += 1
    # Ne jamais dépasser la fin de contrat.
    if subscription.end_date and d > subscription.end_date:
        subscription.status = "paid"
        subscription.save(update_fields=["status"])
        return
    subscription.next_due_date = d
    subscription.status = "dueSoon"
    subscription.save(update_fields=["next_due_date", "status"])


def _month_days(year, month):
    if month == 12:
        nxt = date(year + 1, 1, 1)
    else:
        nxt = date(year, month + 1, 1)
    return (nxt - date(year, month, 1)).days


def _visible_subscriptions(request):
    """Échéances visibles pour ce membre : non archivées —
    et les lignes payroll (salaires) réservées au propriétaire
    (confidentialité, étude §4.1)."""
    qs = Subscription.objects.filter(
        workspace=request.user.profile.workspace,
        archived_at__isnull=True,
    )
    if request.user.profile.role != "owner":
        qs = qs.exclude(category="payroll")
    _refresh_statuses(qs)
    return qs


def _fire_webhooks(workspace, event, payload):
    """POST JSON vers les webhooks actifs abonnés à `event`
    (étude Phase 4 — connecteurs comptables). Échecs ignorés :
    un webhook ne bloque jamais le flux applicatif."""
    try:
        import json as _json
        import urllib.request

        for hook in Webhook.objects.filter(
            workspace=workspace, active=True
        ):
            if event not in (hook.events or ""):
                continue
            body = _json.dumps(
                {"event": event, "data": payload}
            ).encode()
            req = urllib.request.Request(
                hook.url,
                data=body,
                headers={
                    "Content-Type": "application/json",
                    "X-Abonex-Secret": hook.secret,
                },
            )
            try:
                urllib.request.urlopen(req, timeout=5)
            except Exception:
                pass
    except Exception:
        pass


class WebhookListCreateView(generics.ListCreateAPIView):
    """GET/POST /webhooks/ — intégrations externes (étude §4)."""

    permission_classes = [IsOwnerOrManager]
    serializer_class = WebhookSerializer

    def get_queryset(self):
        return Webhook.objects.filter(
            workspace=self.request.user.profile.workspace
        )

    def perform_create(self, serializer):
        serializer.save(
            workspace=self.request.user.profile.workspace
        )


class WebhookDetailView(generics.RetrieveUpdateDestroyAPIView):
    permission_classes = [IsOwnerOrManager]
    serializer_class = WebhookSerializer

    def get_queryset(self):
        return Webhook.objects.filter(
            workspace=self.request.user.profile.workspace
        )


def _audit(request, action, obj_type, obj_repr, before=None, after=None):
    """Écrit une ligne de journal d'audit (étude §4.5)."""
    AuditLog.objects.create(
        workspace=request.user.profile.workspace,
        actor=request.user,
        action=action,
        object_type=obj_type,
        object_repr=str(obj_repr)[:200],
        before=before or {},
        after=after or {},
    )


class SubscriptionListCreateView(generics.ListCreateAPIView):
    """GET /subscriptions/ · POST /subscriptions/"""

    serializer_class = SubscriptionSerializer
    permission_classes = [IsAuthenticated, SubscriptionPermission]

    def get_queryset(self):
        return _visible_subscriptions(self.request)

    def perform_create(self, serializer):
        from datetime import date as _date

        next_due = serializer.validated_data.get("next_due_date")
        # Statut cohérent dès la création : échéance passée → overdue.
        computed = (
            "overdue"
            if next_due and next_due < _date.today()
            else serializer.validated_data.get("status", "dueSoon")
        )
        subscription = serializer.save(
            owner=self.request.user,
            workspace=self.request.user.profile.workspace,
            status=computed,
        )
        _fire_webhooks(
            subscription.workspace,
            "subscription",
            {
                "id": subscription.pk,
                "name": subscription.name,
                "amount": str(subscription.amount),
            },
        )
        _audit(
            self.request,
            "create",
            "subscription",
            subscription.name,
            after={
                "amount": str(subscription.amount),
                "currency": subscription.currency,
                "cycle": subscription.cycle,
            },
        )


class SubscriptionDetailView(generics.RetrieveUpdateDestroyAPIView):
    """GET/PATCH/DELETE /subscriptions/<id>/ — abonnement de l'espace."""

    serializer_class = SubscriptionSerializer
    permission_classes = [IsAuthenticated, SubscriptionPermission]

    def get_queryset(self):
        return _visible_subscriptions(self.request)

    def perform_update(self, serializer):
        profile = self.request.user.profile
        role = profile.role
        marking_paid = self.request.data.get("status") == "paid"
        # Règles d'approbation (étude §4.4/§B) : un assistant
        # déclare toujours en « pending » ; un owner/manager
        # passe aussi en attente SI le montant dépasse le seuil
        # d'approbation configuré sur l'espace.
        declared = self.request.data.get("amount_paid")
        amount = float(
            declared if declared is not None
            else serializer.instance.amount
        )
        threshold = profile.workspace.approval_threshold
        needs_approval = marking_paid and (
            role == "assistant"
            or (threshold is not None and amount > float(threshold))
        )
        if needs_approval:
            subscription = serializer.save(status="dueSoon")
            payment, created = Payment.objects.get_or_create(
                subscription=subscription,
                workspace=self.request.user.profile.workspace,
                due_date=subscription.next_due_date,
                defaults={
                    "recorded_by": self.request.user,
                    "amount": subscription.amount,
                    "amount_paid": declared,
                    "method": self.request.data.get("method", ""),
                    "reference": self.request.data.get("reference", ""),
                    "status": "pending",
                },
            )
            _audit(
                self.request,
                "pay",
                "payment",
                f"{subscription.name} (déclaré)",
                after={"status": "pending"},
            )
            return
        before = {"status": serializer.instance.status}
        subscription = serializer.save()
        if marking_paid:
            Payment.objects.get_or_create(
                subscription=subscription,
                workspace=self.request.user.profile.workspace,
                due_date=subscription.next_due_date,
                defaults={
                    "recorded_by": self.request.user,
                    "amount": subscription.amount,
                    "amount_paid": self.request.data.get("amount_paid"),
                    "method": self.request.data.get("method", ""),
                    "reference": self.request.data.get("reference", ""),
                    "status": "approved",
                    "approved_by": self.request.user,
                },
            )
            # L'échéance payée appartient au passé : on fait avancer
            # la prochaine échéance d'un cycle complet.
            _advance_due(subscription)
            _fire_webhooks(
                self.request.user.profile.workspace,
                "payment",
                {
                    "id": subscription.pk,
                    "name": subscription.name,
                    "amount": str(subscription.amount),
                },
            )
            _audit(
                self.request,
                "pay",
                "payment",
                subscription.name,
                before=before,
                after={"status": "paid"},
            )
        else:
            _audit(
                self.request,
                "update",
                "subscription",
                subscription.name,
                before=before,
                after=self.request.data,
            )

    def perform_destroy(self, instance):
        # Suppression douce : l'échéance est archivée, pas effacée —
        # l'historique de paiements survit (étude §4.5/§4.6).
        instance.archived_at = timezone.now()
        instance.save(update_fields=["archived_at"])
        _audit(
            self.request,
            "delete",
            "subscription",
            instance.name,
            before={
                "amount": str(instance.amount),
                "currency": instance.currency,
            },
        )


class PaymentApprovalView(APIView):
    """POST /payments/<id>/verdict/ — owner/manager (ou capacité
    « payments » des rôles personnalisés) valide ou refuse une
    déclaration de paiement (étude §4.4/B)."""

    def post(self, request, pk):
        profile = request.user.profile
        if profile.role not in {"owner", "manager"} and not has_cap(
            profile, "payments"
        ):
            return Response(status=status.HTTP_403_FORBIDDEN)
        payment = get_object_or_404(
            Payment, pk=pk, workspace=profile.workspace, status="pending"
        )
        verdict = request.data.get("verdict")
        if verdict not in {"approved", "rejected"}:
            return Response(
                {"verdict": ["approved ou rejected attendu."]},
                status=status.HTTP_400_BAD_REQUEST,
            )
        payment.status = verdict
        payment.approved_by = request.user
        payment.rejection_reason = request.data.get("reason", "")
        payment.save(
            update_fields=[
                "status", "approved_by", "rejection_reason"
            ]
        )
        sub = payment.subscription
        if verdict == "approved":
            sub.status = "paid"
            sub.save(update_fields=["status"])
            _advance_due(sub)
            _fire_webhooks(
                payment.workspace,
                "payment",
                {"id": sub.pk, "name": sub.name},
            )
        _audit(
            request,
            verdict.replace("approved", "approve").replace(
                "rejected", "reject"
            ),
            "payment",
            sub.name,
            after={"verdict": verdict},
        )
        return Response({"status": verdict})


class DepartmentListCreateView(generics.ListCreateAPIView):
    """GET/POST /departments/ — centres de coûts de l'espace
    (étude §B). Écriture owner/manager via SubscriptionPermission."""

    serializer_class = DepartmentSerializer
    permission_classes = [IsAuthenticated, SubscriptionPermission]

    def get_queryset(self):
        return Department.objects.filter(
            workspace=self.request.user.profile.workspace
        )

    def perform_create(self, serializer):
        serializer.save(workspace=self.request.user.profile.workspace)


class DepartmentDetailView(generics.RetrieveUpdateDestroyAPIView):
    serializer_class = DepartmentSerializer
    permission_classes = [IsAuthenticated, SubscriptionPermission]

    def get_queryset(self):
        return Department.objects.filter(
            workspace=self.request.user.profile.workspace
        )


class BudgetListCreateView(generics.ListCreateAPIView):
    """GET/POST /budgets/ — budgets par catégorie ou département
    (étude §B). Écriture owner/manager."""

    serializer_class = BudgetSerializer
    permission_classes = [IsAuthenticated, SubscriptionPermission]

    def get_queryset(self):
        return Budget.objects.filter(
            workspace=self.request.user.profile.workspace
        )

    def perform_create(self, serializer):
        serializer.save(workspace=self.request.user.profile.workspace)


class BudgetDetailView(generics.RetrieveUpdateDestroyAPIView):
    serializer_class = BudgetSerializer
    permission_classes = [IsAuthenticated, SubscriptionPermission]

    def get_queryset(self):
        return Budget.objects.filter(
            workspace=self.request.user.profile.workspace
        )


class TreasuryView(APIView):
    """GET /treasury/?days=90&start_balance=X — prévision de
    trésorerie (étude §C) : solde de départ saisi + échéances
    projetées → solde final, solde minimum, première date
    « solde insuffisant ». Multi-devises converti en base."""

    def get(self, request):
        from datetime import timedelta as _td

        profile = request.user.profile
        ws = profile.workspace
        base = ws.default_currency or "XAF"
        days = min(int(request.query_params.get("days") or 90), 365)
        try:
            start = float(request.query_params.get("start_balance") or 0)
        except ValueError:
            start = 0.0
        try:
            rates = rates_for(base) or {}
        except Exception:
            rates = {}

        def to_base(amount, currency):
            if currency == base:
                return float(amount)
            rate = rates.get(currency)
            return float(amount) / rate if rate else None

        # Projection des occurrences : chaque échéance active est
        # reprojetée sur son cycle jusqu'à l'horizon demandé.
        today = timezone.localdate()
        horizon = today + _td(days=days)
        step_days = {
            "daily": 1,
            "weekly": 7,
            "monthly": 30,
            "quarterly": 91,
            "yearly": 365,
            "once": None,
        }
        subs = _visible_subscriptions(request).exclude(
            category="event"
        ).select_related()
        events = []
        for s in subs:
            conv = to_base(s.amount, s.currency)
            if conv is None:
                continue
            step = step_days.get(s.cycle)
            d = s.next_due_date
            if d is None:
                continue
            if step is None:  # ponctuel
                if today <= d <= horizon:
                    events.append((d, conv))
                continue
            while d <= horizon:
                if d >= today:
                    events.append((d, conv))
                d += _td(days=step)
        events.sort()
        # Courbe : solde après chaque échéance — le minimum et la
        # première date négative donnent l'alerte trésorerie.
        balance = start
        min_balance = start
        first_negative = None
        for d, amt in events:
            balance -= amt
            if balance < min_balance:
                min_balance = balance
            if balance < 0 and first_negative is None:
                first_negative = d.isoformat()
        return Response(
            {
                "days": days,
                "base_currency": base,
                "start_balance": start,
                "end_balance": round(balance, 2),
                "min_balance": round(min_balance, 2),
                "total_planned": round(sum(a for _, a in events), 2),
                "events": len(events),
                "first_negative_date": first_negative,
            }
        )


class AttachmentListCreateView(APIView):
    """GET /attachments/?subscription=<id>|payment=<id> — liste
    des justificatifs · POST multipart {file, subscription|payment,
    name?} — upload d'un reçu/facture (étude §C)."""

    permission_classes = [IsAuthenticated, SubscriptionPermission]

    def get(self, request):
        ws = request.user.profile.workspace
        qs = Attachment.objects.filter(workspace=ws)
        sub = request.query_params.get("subscription")
        pay = request.query_params.get("payment")
        if sub:
            qs = qs.filter(subscription_id=sub)
        if pay:
            qs = qs.filter(payment_id=pay)
        return Response(
            AttachmentSerializer(
                qs, many=True, context={"request": request}
            ).data
        )

    def post(self, request):
        ws = request.user.profile.workspace
        uploaded = request.FILES.get("file")
        if uploaded is None:
            return Response(
                {"file": ["Fichier requis."]},
                status=status.HTTP_400_BAD_REQUEST,
            )
        # Rattachement : soit une échéance de l'espace, soit un
        # paiement de l'espace — jamais un objet étranger.
        sub_id = request.data.get("subscription")
        pay_id = request.data.get("payment")
        sub = pay = None
        if sub_id:
            sub = get_object_or_404(
                Subscription, pk=sub_id, workspace=ws
            )
        elif pay_id:
            pay = get_object_or_404(
                Payment, pk=pay_id, workspace=ws
            )
        else:
            return Response(
                {"detail": ["subscription ou payment requis."]},
                status=status.HTTP_400_BAD_REQUEST,
            )
        attachment = Attachment.objects.create(
            workspace=ws,
            subscription=sub,
            payment=pay,
            file=uploaded,
            name=request.data.get("name") or uploaded.name or "",
            uploaded_by=request.user,
        )
        return Response(
            AttachmentSerializer(
                attachment, context={"request": request}
            ).data,
            status=status.HTTP_201_CREATED,
        )


class AttachmentDetailView(APIView):
    """DELETE /attachments/<id>/ — supprime le justificatif
    (owner/manager ou auteur de l'upload)."""

    def delete(self, request, pk):
        profile = request.user.profile
        attachment = get_object_or_404(
            Attachment, pk=pk, workspace=profile.workspace
        )
        if (
            attachment.uploaded_by_id != request.user.id
            and profile.role not in {"owner", "manager"}
        ):
            return Response(status=status.HTTP_403_FORBIDDEN)
        attachment.file.delete(save=False)
        attachment.delete()
        return Response(status=status.HTTP_204_NO_CONTENT)


class CommentListCreateView(APIView):
    """GET/POST /subscriptions/<id>/comments/ — discussion d'une
    échéance (étude §G) : tout membre de l'espace lit et écrit
    ; la suppression se fait côté auteur ou propriétaire via
    /comments/<id>/."""

    def _subscription(self, request, pk):
        return get_object_or_404(
            _visible_subscriptions(request), pk=pk
        )

    def get(self, request, pk):
        subscription = self._subscription(request, pk)
        return Response(
            [
                {
                    "id": c.id,
                    "author": (
                        c.author.get_full_name() or c.author.email
                        if c.author
                        else ""
                    ),
                    "text": c.text,
                    "at": c.created_at,
                }
                for c in subscription.comments.select_related(
                    "author"
                )
            ]
        )

    def post(self, request, pk):
        subscription = self._subscription(request, pk)
        text = (request.data.get("text") or "").strip()
        if not text:
            return Response(
                {"text": ["Commentaire vide."]},
                status=status.HTTP_400_BAD_REQUEST,
            )
        comment = Comment.objects.create(
            workspace=subscription.workspace,
            subscription=subscription,
            author=request.user,
            text=text[:1000],
        )
        return Response({"id": comment.id}, status=status.HTTP_201_CREATED)


class CommentDetailView(APIView):
    """DELETE /comments/<id>/ — auteur ou propriétaire."""

    def delete(self, request, pk):
        profile = request.user.profile
        comment = get_object_or_404(
            Comment, pk=pk, workspace=profile.workspace
        )
        if (
            comment.author_id != request.user.id
            and profile.role != "owner"
        ):
            return Response(status=status.HTTP_403_FORBIDDEN)
        comment.delete()
        return Response(status=status.HTTP_204_NO_CONTENT)


class MonthlyReportEmailView(APIView):
    """POST /report/monthly/send/ — envoie le rapport mensuel
    PDF par e-mail au propriétaire (étude §F/G). Nécessite
    EMAIL_HOST configuré côté serveur."""

    def post(self, request):
        profile = request.user.profile
        if profile.role not in {"owner", "manager"}:
            return Response(status=status.HTTP_403_FORBIDDEN)
        from django.conf import settings as dj_settings
        from django.core.mail import EmailMessage

        if getattr(dj_settings, "EMAIL_HOST", None) is None:
            return Response(
                {"detail": ["SMTP non configuré sur le serveur."]},
                status=status.HTTP_503_SERVICE_UNAVAILABLE,
            )
        # Le PDF du rapport mensuel partage la logique d'export —
        # on réutilise la vue en appelant sa méthode get.
        response = ExportPdfView().get(request)
        pdf_bytes = response.content
        owner = (
            User.objects.filter(
                profile__workspace=profile.workspace,
                profile__role="owner",
            )
            .order_by("id")
            .first()
        )
        recipient = (owner or request.user).email
        mail = EmailMessage(
            subject=f"Rapport mensuel — {profile.workspace.name}",
            body=(
                "Votre rapport de charges mensuel est en pièce "
                "jointe (PDF). — Abonex"
            ),
            to=[recipient],
        )
        mail.attach(
            "rapport_mensuel.pdf", pdf_bytes, "application/pdf"
        )
        mail.send(fail_silently=False)
        return Response({"sent_to": recipient})


class SupplierListCreateView(generics.ListCreateAPIView):
    """GET/POST /suppliers/ — fournisseurs/contrats (étude §E1)."""

    permission_classes = [IsOwnerOrManager]
    serializer_class = SupplierSerializer

    def get_queryset(self):
        return Supplier.objects.filter(
            workspace=self.request.user.profile.workspace
        )

    def perform_create(self, serializer):
        serializer.save(
            workspace=self.request.user.profile.workspace
        )


class SupplierDetailView(generics.RetrieveUpdateDestroyAPIView):
    permission_classes = [IsOwnerOrManager]
    serializer_class = SupplierSerializer

    def get_queryset(self):
        return Supplier.objects.filter(
            workspace=self.request.user.profile.workspace
        )


class PayrollItemListCreateView(generics.ListCreateAPIView):
    """GET/POST /payroll-items/?employee=<id>&period=YYYY-MM —
    primes, avances, retenues, heures supp (étude Phase 3)."""

    permission_classes = [IsOwnerOrManager]
    serializer_class = PayrollItemSerializer

    def get_queryset(self):
        qs = PayrollItem.objects.filter(
            workspace=self.request.user.profile.workspace
        ).select_related("employee")
        for key in ("employee", "period"):
            value = self.request.GET.get(key)
            if value:
                qs = qs.filter(**{key: value})
        return qs

    def perform_create(self, serializer):
        serializer.save(
            workspace=self.request.user.profile.workspace
        )


class PayrollItemDetailView(generics.DestroyAPIView):
    permission_classes = [IsOwnerOrManager]
    serializer_class = PayrollItemSerializer

    def get_queryset(self):
        return PayrollItem.objects.filter(
            workspace=self.request.user.profile.workspace
        )


class PayslipView(APIView):
    """GET /employees/<id>/payslip/?period=YYYY-MM — bulletin de
    paie PDF (étude §D/Phase 3) : en-tête société, salaire,
    éléments du mois, net à payer."""

    permission_classes = [IsOwnerOrManager]

    def get(self, request, pk):
        from reportlab.lib.pagesizes import A4
        from reportlab.lib.units import mm
        from reportlab.pdfgen import canvas
        import io

        ws = request.user.profile.workspace
        emp = get_object_or_404(Employee, pk=pk, workspace=ws)
        period = request.GET.get(
            "period", timezone.localdate().strftime("%Y-%m")
        )
        items = list(emp.payroll_items.filter(period=period))

        def sign(item):
            return (
                -float(item.amount)
                if item.kind
                in {"advance", "deduction", "contribution", "tax"}
                else float(item.amount)
            )

        net = float(emp.salary) + sum(sign(i) for i in items)

        buf = io.BytesIO()
        pdf = canvas.Canvas(buf, pagesize=A4)
        w, h = A4
        y = h - 20 * mm
        pdf.setFont("Helvetica-Bold", 18)
        pdf.drawString(20 * mm, y, ws.legal_name or ws.name)
        y -= 8 * mm
        pdf.setFont("Helvetica-Bold", 13)
        pdf.drawString(
            20 * mm, y, f"Bulletin de paie — {period}"
        )
        y -= 9 * mm
        pdf.setFont("Helvetica", 10)
        pdf.drawString(
            20 * mm, y, f"Employé : {emp.name}"
            + (f" — {emp.position}" if emp.position else "")
        )
        if emp.contract:
            y -= 5 * mm
            pdf.drawString(20 * mm, y, f"Contrat : {emp.contract}")
        if emp.hire_date:
            y -= 5 * mm
            pdf.drawString(
                20 * mm,
                y,
                f"Embauché le : {emp.hire_date:%d/%m/%Y}",
            )
        if emp.payment_info:
            y -= 5 * mm
            pdf.drawString(
                20 * mm, y, f"Versement : {emp.payment_info}"
            )
        y -= 11 * mm
        pdf.setFont("Helvetica-Bold", 11)
        pdf.drawString(20 * mm, y, "Lignes de paie")
        y -= 7 * mm
        pdf.setFont("Helvetica", 10)
        pdf.drawString(
            25 * mm,
            y,
            f"Salaire de base : {float(emp.salary):,.2f} "
            f"{emp.currency}",
        )
        y -= 6 * mm
        for item in items:
            label = dict(PayrollItem.KINDS)[item.kind]
            pdf.drawString(
                25 * mm,
                y,
                f"{label} — {item.label} : "
                f"{sign(item):+,.2f} {emp.currency}",
            )
            y -= 6 * mm
        y -= 5 * mm
        pdf.setFont("Helvetica-Bold", 13)
        pdf.drawString(
            20 * mm,
            y,
            f"NET À PAYER : {net:,.2f} {emp.currency}",
        )
        pdf.showPage()
        pdf.save()

        from django.http import HttpResponse

        resp = HttpResponse(
            buf.getvalue(), content_type="application/pdf"
        )
        resp["Content-Disposition"] = (
            f'attachment; filename="bulletin_{emp.name}_{period}.pdf"'
        )
        return resp


class MyPayslipView(APIView):
    """GET /employees/me/payslip/?period= — portail employé
    (étude §D) : le salarié lié récupère SON bulletin PDF, sans
    droit owner/manager requis."""

    def get(self, request):
        emp = Employee.objects.filter(
            user=request.user,
            workspace=request.user.profile.workspace,
        ).first()
        if emp is None:
            return Response(status=status.HTTP_404_NOT_FOUND)
        return PayslipView().get(request, pk=emp.pk)


class PayAllView(APIView):
    """POST /employees/pay-all/ — paie groupée (étude §D/Phase 3) :
    marque PAYÉES toutes les échéances payroll actives du mois
    en cours, agrégeant les éléments de paie (primes/avances…).
    Retourne le récapitulatif à afficher avant confirmation."""

    permission_classes = [IsOwnerOrManager]

    def post(self, request):
        ws = request.user.profile.workspace
        period = request.data.get(
            "period", timezone.localdate().strftime("%Y-%m")
        )
        results = []
        for emp in ws.employees.filter(active=True).select_related(
            "subscription"
        ):
            sub = emp.subscription
            if sub is None:
                continue
            items = list(emp.payroll_items.filter(period=period))
            net = float(emp.salary) + sum(
                -float(i.amount)
                if i.kind
                in {"advance", "deduction", "contribution", "tax"}
                else float(i.amount)
                for i in items
            )
            sub.amount = net
            sub.save(update_fields=["amount"])
            if sub.status != "paid":
                sub.status = "paid"
                sub.save(update_fields=["status"])
            Payment.objects.update_or_create(
                subscription=sub,
                workspace=ws,
                due_date=sub.next_due_date,
                defaults={
                    "amount": net,
                    "status": "approved",
                    "recorded_by": request.user,
                    "paid_at": timezone.now(),
                },
            )
            results.append({"employee": emp.name, "net": net})
            _audit(
                request, "pay", "payment",
                f"Paie {emp.name} ({period})",
                after={"net": net},
            )
        return Response({"period": period, "paid": results})


class StatementImportView(APIView):
    """POST /import/transactions/ — import de relevé (étude §E) :
    CSV multipart avec des colonnes date/libellé/montant
    (relevé Mobile Money, banque…). Chaque ligne est rapprochée
    d'une échéance par similarité de nom → Payment approuvé.
    Retourne {matched, created, unmatched[]}."""

    parser_classes = [MultiPartParser]
    permission_classes = [IsOwnerOrManager]

    _ALIASES = {
        "date": ("date", "trans_date", "transaction date"),
        "label": ("label", "libelle", "libellé", "description",
                  "details", "détails", "opération"),
        "amount": ("amount", "montant", "debit", "débit",
                   "withdrawal", "retrait"),
    }

    def post(self, request):
        import csv
        import io
        from decimal import Decimal, InvalidOperation

        upload = request.FILES.get("file")
        if upload is None:
            return Response(
                {"detail": "Fichier CSV requis (champ 'file')."},
                status=status.HTTP_400_BAD_REQUEST,
            )
        try:
            text = upload.read().decode("utf-8-sig", errors="ignore")
        except Exception:
            return Response(
                {"detail": "Lecture du fichier impossible."},
                status=status.HTTP_400_BAD_REQUEST,
            )
        sample = text[:2048]
        delimiter = ";" if sample.count(";") > sample.count(",") else ","
        reader = csv.DictReader(io.StringIO(text), delimiter=delimiter)
        if not reader.fieldnames:
            return Response(
                {"detail": "CSV sans en-tête lisible."},
                status=status.HTTP_400_BAD_REQUEST,
            )
        fields = {f.strip().lower(): f for f in reader.fieldnames}

        def pick(key):
            for alias in self._ALIASES[key]:
                if alias in fields:
                    return fields[alias]
            return None

        date_col = pick("date")
        label_col = pick("label") or next(
            iter(fields.values()), None
        )
        amount_col = pick("amount")
        ws = request.user.profile.workspace
        subs = list(
            Subscription.objects.filter(
                workspace=ws, archived_at__isnull=True
            )
        )
        matched = created = 0
        unmatched = []
        for row in reader:
            label = (row.get(label_col) or "").strip()
            if not label:
                continue
            norm = label.lower()
            best = None
            for s in subs:
                for needle in (s.name.lower(), s.provider.lower()):
                    if needle and needle in norm:
                        best = s
                        break
                if best:
                    break
            if best is None:
                unmatched.append(label[:80])
                continue
            matched += 1
            try:
                amount = Decimal(
                    (row.get(amount_col) or "0")
                    .replace(" ", "")
                    .replace(",", ".")
                ) if amount_col else best.amount
            except (InvalidOperation, AttributeError):
                amount = best.amount
            raw_date = (row.get(date_col) or "").strip()[:10]
            try:
                paid_date = (
                    datetime.strptime(raw_date, "%Y-%m-%d").date()
                    if len(raw_date) >= 8
                    else timezone.localdate()
                )
            except ValueError:
                try:
                    paid_date = datetime.strptime(
                        raw_date, "%d/%m/%Y"
                    ).date()
                except ValueError:
                    paid_date = timezone.localdate()
            payment, is_new = Payment.objects.get_or_create(
                subscription=best,
                workspace=ws,
                due_date=best.next_due_date,
                defaults={
                    "recorded_by": request.user,
                    "amount": abs(amount),
                    "amount_paid": abs(amount),
                    "method": "import",
                    "reference": label[:120],
                    "status": "approved",
                    "approved_by": request.user,
                    "paid_at": timezone.now(),
                },
            )
            if is_new:
                created += 1
                best.status = "paid"
                best.save(update_fields=["status"])
                _advance_due(best)
                _fire_webhooks(
                    ws,
                    "payment",
                    {"id": best.pk, "name": best.name,
                     "via": "import"},
                )
        _audit(
            request,
            "import",
            "statement",
            getattr(upload, "name", "csv"),
            after={"matched": matched, "created": created},
        )
        return Response(
            {
                "matched": matched,
                "created": created,
                "unmatched": unmatched[:50],
            }
        )


class PendingPaymentsView(APIView):
    """GET /payments/ — déclarations de paiement en attente
    de validation (owner/manager, ou capacité « payments »
    des rôles personnalisés)."""

    def get(self, request):
        profile = request.user.profile
        if profile.role not in {"owner", "manager"} and not has_cap(
            profile, "payments"
        ):
            return Response(status=status.HTTP_403_FORBIDDEN)
        payments = (
            Payment.objects.filter(
                workspace=profile.workspace, status="pending"
            )
            .select_related("subscription", "recorded_by")
            .order_by("due_date")
        )
        return Response(
            [
                {
                    "id": p.id,
                    "subscription_id": p.subscription_id,
                    "name": p.subscription.name,
                    "amount": str(p.amount),
                    "amount_paid": (
                        str(p.amount_paid) if p.amount_paid is not None
                        else None
                    ),
                    "currency": p.subscription.currency,
                    "due_date": p.due_date,
                    "method": p.method,
                    "reference": p.reference,
                    "declared_by": (
                        p.recorded_by.get_full_name() or p.recorded_by.email
                        if p.recorded_by
                        else ""
                    ),
                }
                for p in payments
            ]
        )


class MembershipListView(APIView):
    """GET /memberships/ — espaces accessibles à l'utilisateur
    (étude §4.2). Crée à la volée le membership de l'espace
    courant pour les comptes antérieurs au modèle."""

    def get(self, request):
        profile = request.user.profile
        # Compte pré-Membership : l'espace actif n'a pas encore
        # de ligne — on l'enregistre (lazy backfill).
        Membership.objects.get_or_create(
            user=request.user,
            workspace=profile.workspace,
            defaults={"role": profile.role},
        )
        memberships = (
            Membership.objects.filter(
                user=request.user, status="active"
            )
            .select_related("workspace")
            .order_by("created_at")
        )
        return Response(
            [
                {
                    "id": m.id,
                    "workspace_id": m.workspace_id,
                    "name": m.workspace.name,
                    "kind": m.workspace.kind,
                    "role": m.role,
                    "active": m.workspace_id == profile.workspace_id,
                }
                for m in memberships
            ]
        )


class MembershipActivateView(APIView):
    """POST /memberships/<id>/activate/ — bascule l'espace actif
    : profile.workspace/role reflètent le membership choisi —
    tout le code existant (permissions, requêtes) suit
    automatiquement (étude §4.2)."""

    def post(self, request, pk):
        membership = get_object_or_404(
            Membership.objects.select_related("workspace"),
            pk=pk,
            user=request.user,
            status="active",
        )
        profile = request.user.profile
        profile.workspace = membership.workspace
        profile.role = membership.role
        profile.save(update_fields=["workspace", "role"])
        _audit(
            request,
            "update",
            "workspace",
            f"Espace actif : {membership.workspace.name}",
        )
        return Response(
            UserSerializer(request.user, context={"request": request}).data
        )


class MembershipPermissionsView(APIView):
    """PATCH /memberships/<id>/permissions/ — propriétaire
    accorde des capacités additionnelles au membre (rôles
    personnalisés, étude Phase 4) : {custom_permissions:
    "employees,payments,budgets,audit"}."""

    permission_classes = [IsOwner]

    CAPS = {"employees", "payments", "budgets", "audit"}

    def patch(self, request, pk):
        membership = get_object_or_404(
            Membership,
            pk=pk,
            workspace=request.user.profile.workspace,
        )
        raw = request.data.get("custom_permissions") or ""
        caps = {
            c.strip() for c in str(raw).split(",") if c.strip()
        }
        invalid = caps - self.CAPS
        if invalid:
            return Response(
                {"custom_permissions": [
                    f"Capacités inconnues : {', '.join(invalid)}"
                ]},
                status=status.HTTP_400_BAD_REQUEST,
            )
        membership.custom_permissions = ",".join(sorted(caps))
        membership.save(update_fields=["custom_permissions"])
        _audit(
            request,
            "role_change",
            "membership",
            membership.user.email,
            after={"custom_permissions": membership.custom_permissions},
        )
        return Response(
            {"custom_permissions": membership.custom_permissions}
        )


class AuditLogView(generics.ListAPIView):
    """GET /audit/ — journal d'audit de l'espace, propriétaire
    uniquement (étude §4.5)."""

    permission_classes = [IsOwner]

    def get(self, request):
        logs = request.user.profile.workspace.audit_logs.select_related(
            "actor"
        )[:200]
        return Response(
            [
                {
                    "id": log.id,
                    "actor": (
                        log.actor.get_full_name() or log.actor.email
                        if log.actor
                        else ""
                    ),
                    "action": log.action,
                    "object_type": log.object_type,
                    "object_repr": log.object_repr,
                    "before": log.before,
                    "after": log.after,
                    "at": log.created_at,
                }
                for log in logs
            ]
        )


class PaymentHistoryView(generics.ListAPIView):
    serializer_class = PaymentSerializer
    permission_classes = [IsAuthenticated, SubscriptionPermission]

    def get_queryset(self):
        workspace = self.request.user.profile.workspace
        subscription = get_object_or_404(
            Subscription,
            workspace=workspace,
            pk=self.kwargs["pk"],
        )
        return Payment.objects.filter(
            workspace=workspace,
            subscription=subscription,
        )


# ------------------------------------------------------------------
# Configuration de premier démarrage (pays, devises) — boss point 2
# ------------------------------------------------------------------

class WorkspaceBudgetView(APIView):

    def get(self, request):
        return Response(WorkspaceBudgetSerializer(request.user.profile.workspace).data)

    def patch(self, request):
        if request.user.profile.role not in {"owner", "manager"}:
            return Response(status=status.HTTP_403_FORBIDDEN)
        serializer = WorkspaceBudgetSerializer(
            request.user.profile.workspace, data=request.data, partial=True,
        )
        serializer.is_valid(raise_exception=True)
        serializer.save()
        return Response(serializer.data)


class WorkspaceSetupView(APIView):
    """PATCH /workspace/setup/ — configure pays + devises.
    Marque le workspace comme configuré."""


    def patch(self, request):
        # La config concerne TOUT l'espace : seuls owner/manager
        # peuvent la modifier (cohérent avec le budget) — mais le
        # TYPE de compte (kind) est réservé au propriétaire : un
        # gestionnaire ne doit pas basculer l'espace (étude §4.7).
        if request.user.profile.role not in {"owner", "manager"}:
            return Response(status=status.HTTP_403_FORBIDDEN)
        if (
            "kind" in request.data
            and request.data["kind"] != request.user.profile.workspace.kind
            and request.user.profile.role != "owner"
        ):
            return Response(
                {"kind": ["Type de compte réservé au propriétaire."]},
                status=status.HTTP_403_FORBIDDEN,
            )
        workspace = request.user.profile.workspace
        serializer = WorkspaceSerializer(
            workspace, data=request.data, partial=True
        )
        serializer.is_valid(raise_exception=True)
        serializer.save(configured=True)
        # contexte request → avatar_url absolue (sinon l'app reçoit
        # "/media/…" sans hôte et NetworkImage échoue).
        return Response(
            UserSerializer(
                request.user, context={"request": request}
            ).data
        )


# ------------------------------------------------------------------
# Invitations d'équipe par email — boss point 2
# ------------------------------------------------------------------

class InviteListCreateView(generics.ListCreateAPIView):
    """GET /invites/ (liste) · POST /invites/ {email, role}.
    Réservé owner/manager — l'invité confirme via le lien reçu."""


    def _allowed(self, request):
        return request.user.profile.role in {"owner", "manager"}

    def get_queryset(self):
        return Invitation.objects.filter(
            workspace=self.request.user.profile.workspace
        ).order_by("-created_at")

    def list(self, request, *args, **kwargs):
        if not self._allowed(request):
            return Response(status=status.HTTP_403_FORBIDDEN)
        data = [
            {
                "id": str(i.id),
                "email": i.email,
                "role": i.role,
                "status": i.status,
            }
            for i in self.get_queryset()
        ]
        return Response(data)

    def create(self, request, *args, **kwargs):
        if not self._allowed(request):
            return Response(status=status.HTTP_403_FORBIDDEN)
        email = (request.data.get("email") or "").strip().lower()
        role = request.data.get("role") or "viewer"
        if "@" not in email:
            return Response(
                {"email": "Email invalide."},
                status=status.HTTP_400_BAD_REQUEST,
            )
        if role not in {"manager", "assistant", "viewer"}:
            return Response(
                {"role": "Rôle non autorisé."},
                status=status.HTTP_400_BAD_REQUEST,
            )
        workspace = request.user.profile.workspace
        # Un compte existant PEUT être invité : l'acceptation le
        # rattache à cet espace (il quitte l'ancien).
        existing_user = User.objects.filter(email=email).exists()
        invite, _ = Invitation.objects.update_or_create(
            workspace=workspace,
            email=email,
            defaults={
                "role": role,
                "token": secrets.token_urlsafe(32),
                "invited_by": request.user,
                "status": "pending",
            },
        )
        # Email best-effort : en dev (console backend) le lien
        # s'affiche dans les logs du serveur.
        link = f"abonex://invite/{invite.token}"
        try:
            send_mail(
                "Invitation Abonex",
                f"Vous êtes invité à rejoindre {workspace.name} "
                f"en tant que {role}. Ouvrez : {link}",
                None,
                [email],
                fail_silently=True,
            )
        except Exception:
            pass
        return Response(
            {
                "id": str(invite.id),
                "email": invite.email,
                "role": invite.role,
                "status": invite.status,
                # Renvoyé aussi à l'appelant pour partage manuel
                # (WhatsApp…) — l'email SMTP n'est pas garanti.
                "invite_url": link,
                # True si l'invité a déjà un compte Abonex : il sera
                # rattaché à cet espace en acceptant.
                "existing_user": existing_user,
            },
            status=status.HTTP_201_CREATED,
        )


class InviteAcceptView(APIView):
    """POST /invites/accept/ {token, password, first_name, last_name}
    → crée le compte invité dans l'espace qui l'a invité."""

    permission_classes = [AllowAny]
    throttle_scope = "password"

    def post(self, request):
        token = request.data.get("token") or ""
        password = request.data.get("password") or ""
        invite = get_object_or_404(
            Invitation.objects.select_related("workspace"),
            token=token,
            status="pending",
        )
        # Le lien n'est pas éternel : 7 jours comme tout jeton
        # d'invitation raisonnable.
        if timezone.now() - invite.created_at > timedelta(days=7):
            return Response(
                {"token": "Invitation expirée — demandez-en une "
                          "nouvelle à l'invitant."},
                status=status.HTTP_400_BAD_REQUEST,
            )
        # Un compte peut déjà exister pour cet email (invité déjà
        # inscrit ailleurs) : on le rattache à l'espace invité au
        # lieu de crasher sur la contrainte d'unicité.
        user = User.objects.filter(email=invite.email).first()
        if user is None:
            if len(password) < 8:
                return Response(
                    {"password": "8 caractères minimum."},
                    status=status.HTTP_400_BAD_REQUEST,
                )
            user = User.objects.create_user(
                username=invite.email,
                email=invite.email,
                password=password,
                first_name=(request.data.get("first_name") or "").strip(),
                last_name=(request.data.get("last_name") or "").strip(),
            )
        profile = getattr(user, "profile", None)
        if profile is None:
            Profile.objects.create(
                user=user, workspace=invite.workspace, role=invite.role
            )
        else:
            # Multi-espaces (§4.2) : l'ancien espace reste
            # accessible via son membership — l'utilisateur
            # peut revenir à son espace perso à tout moment.
            Membership.objects.update_or_create(
                user=user,
                workspace=profile.workspace,
                defaults={"role": profile.role, "status": "active"},
            )
            profile.workspace = invite.workspace
            profile.role = invite.role
            profile.save(update_fields=["workspace", "role"])
        # Le membership du nouvel espace : créé ou réactivé
        # (ré-invitation d'un membre suspendu).
        Membership.objects.update_or_create(
            user=user,
            workspace=invite.workspace,
            defaults={"role": invite.role, "status": "active"},
        )
        invite.status = "accepted"
        invite.save(update_fields=["status"])
        refresh = RefreshToken.for_user(user)
        return Response(
            {
                "access": str(refresh.access_token),
                "refresh": str(refresh),
                "user": UserSerializer(
                    user, context={"request": request}
                ).data,
            },
            status=status.HTTP_201_CREATED,
        )


# ------------------------------------------------------------------
# Catalogue de fournisseurs par pays — boss point 3
# ------------------------------------------------------------------

class ProviderCatalogView(APIView):
    """GET /providers/catalog/ → fournisseurs suggérés pour le pays
    du workspace (ou ?country=XX)."""


    def get(self, request):
        country = (
            request.query_params.get("country")
            or request.user.profile.workspace.country
        )
        return Response(providers_for(country))


# ------------------------------------------------------------------
# Connecteurs externes (OVH, IONOS…) — boss point 3
# ------------------------------------------------------------------

class ConnectorListView(APIView):
    """GET /connectors/ → connecteurs disponibles + leurs champs.
    Inclut groupe d'affichage, pays couverts et indicateur de
    disponibilité pour le pays du workspace."""


    def get(self, request):
        country = (request.user.profile.workspace.country or "").upper()
        return Response([
            {
                "slug": c.slug,
                "label": c.label,
                "description": c.description,
                "auth_fields": c.auth_fields,
                "group": connector_meta(c.slug)["group"],
                "oauth": getattr(c, "oauth", False),
                "countries": connector_meta(c.slug)["countries"],
                "available": (
                    "*" in connector_meta(c.slug)["countries"]
                    or country in connector_meta(c.slug)["countries"]
                ),
            }
            for c in CONNECTORS.values()
        ])


class ConnectorSyncView(APIView):
    """POST /connectors/<slug>/sync/ {credentials:{...}}
    → appelle l'API externe et renvoie les abonnements détectés.
    Les credentials sont chiffrés et stockés pour les syncs futures."""


    def post(self, request, slug):
        connector = get_connector(slug)
        if connector is None:
            return Response(
                {"detail": "Connecteur inconnu."},
                status=status.HTTP_404_NOT_FOUND,
            )
        credentials = request.data.get("credentials") or {}
        missing = [
            f["key"] for f in connector.auth_fields
            if f.get("secret") and not credentials.get(f["key"])
        ]
        if missing:
            return Response(
                {"detail": f"Champs manquants : {', '.join(missing)}"},
                status=status.HTTP_400_BAD_REQUEST,
            )
        try:
            items = connector.fetch(credentials)
        except Exception as exc:
            return Response(
                {"detail": f"Connexion au fournisseur impossible : {exc}"},
                status=status.HTTP_502_BAD_GATEWAY,
            )
        # Mémorise la connexion chiffrée pour les prochaines syncs.
        ProviderConnection.objects.update_or_create(
            workspace=request.user.profile.workspace,
            provider=slug,
            label=credentials.get("label") or connector.label,
            defaults={
                "credentials_encrypted": crypto.encrypt(
                    json.dumps(credentials)
                ),
            },
        )
        return Response({"subscriptions": items, "count": len(items)})


class PowensLoginView(APIView):
    """GET /connectors/powens/login/ → {auth_url}
    URL du webview bancaire Powens à ouvrir côté app (OAuth PSD2 —
    les identifiants bancaires ne passent jamais par Abonex)."""


    def get(self, request):
        if not powens_configured():
            return Response(
                {
                    "detail": (
                        "Agrégation bancaire non configurée : renseigner "
                        "POWENS_CLIENT_ID et POWENS_CLIENT_SECRET "
                        "côté serveur."
                    )
                },
                status=status.HTTP_503_SERVICE_UNAVAILABLE,
            )
        country = request.user.profile.workspace.country or "fr"
        # Nonce anti-CSRF : le callback doit le renvoyer pour prouver
        # qu'il prolonge CETTE demande de connexion, pas une autre.
        state = secrets.token_urlsafe(24)
        cache.set(f"powens_state:{request.user.pk}", state, timeout=600)
        return Response(
            {"auth_url": powens_auth_url(country, state), "state": state}
        )


class PowensCallbackView(APIView):
    """POST /connectors/powens/callback/ {code, state}
    Échange le code OAuth → access_token, mémorise la connexion
    chiffrée et renvoie les abonnements détectés dans le relevé."""


    def post(self, request):
        code = request.data.get("code")
        if not code:
            return Response(
                {"code": "Code manquant."},
                status=status.HTTP_400_BAD_REQUEST,
            )
        # Le state lie le callback à la demande de connexion —
        # usage unique, on le consomme quoi qu'il arrive.
        state_key = f"powens_state:{request.user.pk}"
        expected = cache.get(state_key)
        cache.delete(state_key)
        if not expected or request.data.get("state") != expected:
            return Response(
                {"state": "Session OAuth expirée — recommencez "
                          "la connexion bancaire."},
                status=status.HTTP_400_BAD_REQUEST,
            )
        if not powens_configured():
            return Response(
                {"detail": "Agrégation bancaire non configurée."},
                status=status.HTTP_503_SERVICE_UNAVAILABLE,
            )
        try:
            token_data = powens_exchange_code(code)
            access_token = token_data["access_token"]
            items = get_connector("powens").fetch(
                {"access_token": access_token}
            )
        except Exception as exc:
            return Response(
                {"detail": f"Connexion bancaire impossible : {exc}"},
                status=status.HTTP_502_BAD_GATEWAY,
            )
        ProviderConnection.objects.update_or_create(
            workspace=request.user.profile.workspace,
            provider="powens",
            label="Ma banque",
            defaults={
                "credentials_encrypted": crypto.encrypt(
                    json.dumps({"access_token": access_token})
                ),
            },
        )
        return Response({"subscriptions": items, "count": len(items)})


class ConnectionListView(APIView):
    """GET /connections/ → comptes externes connectés au workspace.
    Les identifiants ne sont JAMAIS renvoyés — id + libellé seulement.
    DELETE /connections/<id>/ → déconnecte le compte."""


    def get(self, request):
        conns = ProviderConnection.objects.filter(
            workspace=request.user.profile.workspace
        ).order_by("provider", "label")
        return Response([
            {
                "id": c.id,
                "provider": c.provider,
                "provider_label": (
                    get_connector(c.provider).label
                    if get_connector(c.provider)
                    else c.provider
                ),
                "label": c.label,
                "connected_at": c.created_at,
            }
            for c in conns
        ])


class ConnectionResyncView(APIView):
    """POST /connections/<id>/resync/ → relance fetch() avec les
    credentials chiffrés stockés — re-synchronisation en un tap.
    DELETE /connections/<id>/resync/ → supprime la connexion."""


    def _get_connection(self, request, pk):
        return get_object_or_404(
            ProviderConnection,
            pk=pk,
            workspace=request.user.profile.workspace,
        )

    def post(self, request, pk):
        conn = self._get_connection(request, pk)
        connector = get_connector(conn.provider)
        if connector is None:
            return Response(
                {"detail": "Connecteur introuvable."},
                status=status.HTTP_404_NOT_FOUND,
            )
        try:
            credentials = json.loads(
                crypto.decrypt(conn.credentials_encrypted)
            )
            items = connector.fetch(credentials)
        except Exception as exc:
            return Response(
                {"detail": f"Connexion au fournisseur impossible : {exc}"},
                status=status.HTTP_502_BAD_GATEWAY,
            )
        return Response({"subscriptions": items, "count": len(items)})

    def delete(self, request, pk):
        conn = self._get_connection(request, pk)
        conn.delete()
        return Response(status=status.HTTP_204_NO_CONTENT)


class ExchangeRatesView(APIView):
    """GET /rates/?base=XAF → taux de change réels (cache 12 h).
    Permet à l'app de convertir les montants étrangers
    dans la devise locale de l'utilisateur."""


    def get(self, request):
        base = request.query_params.get("base") or (
            request.user.profile.workspace.default_currency or "USD"
        )
        try:
            return Response(rates_for(base))
        except Exception:
            return Response(
                {"detail": "Service de taux indisponible."},
                status=status.HTTP_502_BAD_GATEWAY,
            )


class AppVersionView(APIView):
    """GET /meta/app-version/ → dernière version publiée + lien
    de téléchargement. Le mobile compare avec sa version
    installée et propose la mise à jour.
    Config : APP_LATEST_VERSION / APP_UPDATE_URL (env)."""


    def get(self, request):
        return Response(
            {
                "latest_version": os.environ.get(
                    "APP_LATEST_VERSION", "1.0.0"
                ),
                "update_url": os.environ.get(
                    "APP_UPDATE_URL",
                    "https://play.google.com/store/apps/details"
                    "?id=com.abonex.abonex",
                ),
            }
        )


class SubscriptionBulkCreateView(APIView):
    """POST /subscriptions/bulk/ {items:[{...}]} → import en masse
    (CSV côté app ou résultat d'un connecteur)."""


    def post(self, request):
        profile = request.user.profile
        if profile.role not in {"owner", "manager"}:
            return Response(status=status.HTTP_403_FORBIDDEN)
        items = request.data.get("items") or []
        if not isinstance(items, list) or not items:
            return Response(
                {"items": "Liste vide."},
                status=status.HTTP_400_BAD_REQUEST,
            )
        # Déduplication : ré-importer le même CSV ou re-synchroniser
        # un connecteur ne doit pas recréer les mêmes abonnements.
        # Clé : fournisseur (ou nom à défaut) + montant + devise.
        existing = {
            (
                (s.provider or s.name).strip().lower(),
                str(s.amount),
                s.currency,
            )
            for s in Subscription.objects.filter(
                workspace=profile.workspace
            )
        }
        created, errors, skipped = [], [], []
        truncated = max(0, len(items) - 500)
        for i, raw in enumerate(items[:500]):
            if not raw.get("next_due_date"):
                # Import : une échéance est obligatoire — par défaut
                # dans 30 jours pour ne pas bloquer l'utilisateur.
                raw = {**raw,
                       "next_due_date": (
                           date.today() + timedelta(days=30)
                       ).isoformat()}
            serializer = SubscriptionSerializer(data=raw)
            if not serializer.is_valid():
                errors.append({"index": i, "errors": serializer.errors})
                continue
            data = serializer.validated_data
            key = (
                str(data.get("provider") or data.get("name") or "")
                .strip().lower(),
                str(data.get("amount")),
                data.get("currency"),
            )
            if key in existing:
                skipped.append({"index": i, "name": data.get("name")})
                continue
            serializer.save(
                owner=request.user, workspace=profile.workspace
            )
            existing.add(key)
            created.append(serializer.data)
        return Response(
            {
                "created": len(created),
                "skipped": len(skipped),
                "duplicates": skipped,
                "truncated": truncated,
                "errors": errors,
            },
            status=status.HTTP_201_CREATED if created or skipped
            else status.HTTP_400_BAD_REQUEST,
        )
