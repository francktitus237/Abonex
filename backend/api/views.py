import json
import os
import secrets
import uuid
from datetime import date, timedelta

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
    Employee, Invitation, Payment, Profile, ProviderConnection,
    Subscription, Workspace,
)
from .serializers import (
    EmployeeSerializer, PaymentSerializer, SubscriptionSerializer,
    UserSerializer, WorkspaceSerializer, WorkspaceBudgetSerializer,
)


from .permissions import (
    IsOwner, SubscriptionPermission,
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

    permission_classes = [SubscriptionPermission]

    def get(self, request):
        ws = request.user.profile.workspace
        return Response(
            EmployeeSerializer(
                ws.employees.all(), many=True
            ).data
        )

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

    permission_classes = [SubscriptionPermission]

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
        for s in Subscription.objects.filter(workspace=ws):
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
            w.writerow(
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


class UserListView(generics.ListAPIView):
    """GET /users/ — réservé au Propriétaire."""

    serializer_class = UserSerializer
    permission_classes = [IsOwner]

    def get_queryset(self):
        return User.objects.select_related("profile").filter(
            profile__workspace=self.request.user.profile.workspace
        ).order_by("id")


class UserDetailView(generics.UpdateAPIView):
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
        return super().update(request, *args, **kwargs)


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


class SubscriptionListCreateView(generics.ListCreateAPIView):
    """GET /subscriptions/ · POST /subscriptions/"""

    serializer_class = SubscriptionSerializer
    permission_classes = [IsAuthenticated, SubscriptionPermission]

    def get_queryset(self):
        qs = Subscription.objects.filter(
            workspace=self.request.user.profile.workspace
        )
        _refresh_statuses(qs)
        return qs

    def perform_create(self, serializer):
        from datetime import date as _date

        next_due = serializer.validated_data.get("next_due_date")
        # Statut cohérent dès la création : échéance passée → overdue.
        computed = (
            "overdue"
            if next_due and next_due < _date.today()
            else serializer.validated_data.get("status", "dueSoon")
        )
        serializer.save(
            owner=self.request.user,
            workspace=self.request.user.profile.workspace,
            status=computed,
        )


class SubscriptionDetailView(generics.RetrieveUpdateDestroyAPIView):
    """GET/PATCH/DELETE /subscriptions/<id>/ — abonnement de l'espace."""

    serializer_class = SubscriptionSerializer
    permission_classes = [IsAuthenticated, SubscriptionPermission]

    def get_queryset(self):
        qs = Subscription.objects.filter(
            workspace=self.request.user.profile.workspace
        )
        _refresh_statuses(qs)
        return qs

    def perform_update(self, serializer):
        subscription = serializer.save()
        if self.request.data.get("status") == "paid":
            Payment.objects.get_or_create(
                subscription=subscription,
                workspace=self.request.user.profile.workspace,
                due_date=subscription.next_due_date,
                defaults={
                    "recorded_by": self.request.user,
                    "amount": subscription.amount,
                },
            )
            # L'échéance payée appartient au passé : on fait avancer
            # la prochaine échéance d'un cycle complet.
            _advance_due(subscription)


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
        # peuvent la modifier (cohérent avec le budget).
        if request.user.profile.role not in {"owner", "manager"}:
            return Response(status=status.HTTP_403_FORBIDDEN)
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
            profile.workspace = invite.workspace
            profile.role = invite.role
            profile.save(update_fields=["workspace", "role"])
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
