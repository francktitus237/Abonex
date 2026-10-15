import json
import secrets
import uuid

from django.contrib.auth import authenticate
from django.contrib.auth.models import User
from django.core.mail import send_mail
from django.shortcuts import get_object_or_404
from rest_framework import generics, status
from rest_framework.permissions import SAFE_METHODS, AllowAny, BasePermission, IsAuthenticated
from rest_framework.response import Response
from rest_framework.views import APIView
from rest_framework_simplejwt.tokens import RefreshToken

from . import crypto
from .catalog import providers_for
from .connectors import CONNECTORS, get_connector
from .rates import rates_for
from .models import (
    Invitation, Payment, Profile, ProviderConnection,
    Subscription, Workspace,
)
from .serializers import (
    PaymentSerializer, SubscriptionSerializer, UserSerializer,
    WorkspaceSerializer,
)


class IsOwner(BasePermission):
    def has_permission(self, request, view):
        profile = getattr(request.user, "profile", None)
        return bool(profile and profile.role == "owner")


class SubscriptionPermission(BasePermission):
    def has_permission(self, request, view):
        profile = getattr(request.user, "profile", None)
        if not profile:
            return False
        if request.method in SAFE_METHODS:
            return True
        if request.method == "DELETE":
            return profile.role == "owner"
        if request.method == "POST":
            return profile.role in {"owner", "manager"}
        if request.method in {"PATCH", "PUT"}:
            if profile.role in {"owner", "manager"}:
                return True
            return profile.role == "assistant" and set(request.data) == {"status"} and request.data.get("status") == "paid"
        return False


class LoginView(APIView):
    """POST /auth/login/ {email, password} → {access, refresh, user}"""

    permission_classes = [AllowAny]

    def post(self, request):
        email = (request.data.get("email") or "").strip().lower()
        password = request.data.get("password") or ""
        try:
            user = User.objects.get(email=email)
        except User.DoesNotExist:
            user = None
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
                "user": UserSerializer(auth_user).data,
            }
        )


class RegisterView(APIView):
    """POST /auth/register/ → crée le compte + profil, renvoie
    {access, refresh, user} comme /auth/login/."""

    permission_classes = [AllowAny]

    def post(self, request):
        email = (request.data.get("email") or "").strip().lower()
        password = request.data.get("password") or ""
        first_name = (request.data.get("first_name") or "").strip()
        last_name = (request.data.get("last_name") or "").strip()

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
        # L'inscrit est propriétaire de son propre espace de travail.
        workspace = Workspace.objects.create(
            name=f"Espace de {first_name or email}"
        )
        Profile.objects.create(user=user, workspace=workspace, role="owner")

        refresh = RefreshToken.for_user(user)
        return Response(
            {
                "access": str(refresh.access_token),
                "refresh": str(refresh),
                "user": UserSerializer(user).data,
            },
            status=status.HTTP_201_CREATED,
        )


class MeView(APIView):
    """GET /auth/me/ → user"""

    def get(self, request):
        return Response(UserSerializer(request.user).data)


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
    """POST /auth/password/forgot/ → toujours 204 (anti-énumération)."""

    permission_classes = [AllowAny]

    def post(self, request):
        return Response(status=status.HTTP_204_NO_CONTENT)


class ResetPasswordView(APIView):
    permission_classes = [AllowAny]

    def post(self, request):
        return Response(status=status.HTTP_204_NO_CONTENT)


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


class SubscriptionListCreateView(generics.ListCreateAPIView):
    """GET /subscriptions/ · POST /subscriptions/"""

    serializer_class = SubscriptionSerializer
    permission_classes = [IsAuthenticated, SubscriptionPermission]

    def get_queryset(self):
        return Subscription.objects.filter(
            workspace=self.request.user.profile.workspace
        )

    def perform_create(self, serializer):
        serializer.save(
            owner=self.request.user,
            workspace=self.request.user.profile.workspace,
        )


class SubscriptionDetailView(generics.RetrieveUpdateDestroyAPIView):
    """GET/PATCH/DELETE /subscriptions/<id>/ — abonnement de l'espace."""

    serializer_class = SubscriptionSerializer
    permission_classes = [IsAuthenticated, SubscriptionPermission]

    def get_queryset(self):
        return Subscription.objects.filter(
            workspace=self.request.user.profile.workspace
        )

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

class WorkspaceSetupView(APIView):
    """PATCH /workspace/setup/ — configure pays + devises.
    Marque le workspace comme configuré."""

    permission_classes = [IsAuthenticated]

    def patch(self, request):
        workspace = request.user.profile.workspace
        serializer = WorkspaceSerializer(
            workspace, data=request.data, partial=True
        )
        serializer.is_valid(raise_exception=True)
        serializer.save(configured=True)
        return Response(UserSerializer(request.user).data)


# ------------------------------------------------------------------
# Invitations d'équipe par email — boss point 2
# ------------------------------------------------------------------

class InviteListCreateView(generics.ListCreateAPIView):
    """GET /invites/ (liste) · POST /invites/ {email, role}.
    Réservé owner/manager — l'invité confirme via le lien reçu."""

    permission_classes = [IsAuthenticated]

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
        # Un compte actif existe déjà → on refuse l'invite.
        if User.objects.filter(email=email).exists():
            return Response(
                {"email": "Cet utilisateur a déjà un compte."},
                status=status.HTTP_400_BAD_REQUEST,
            )
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
            },
            status=status.HTTP_201_CREATED,
        )


class InviteAcceptView(APIView):
    """POST /invites/accept/ {token, password, first_name, last_name}
    → crée le compte invité dans l'espace qui l'a invité."""

    permission_classes = [AllowAny]

    def post(self, request):
        token = request.data.get("token") or ""
        password = request.data.get("password") or ""
        invite = get_object_or_404(Invitation, token=token, status="pending")
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
        Profile.objects.create(
            user=user, workspace=invite.workspace, role=invite.role
        )
        invite.status = "accepted"
        invite.save(update_fields=["status"])
        refresh = RefreshToken.for_user(user)
        return Response(
            {
                "access": str(refresh.access_token),
                "refresh": str(refresh),
                "user": UserSerializer(user).data,
            },
            status=status.HTTP_201_CREATED,
        )


# ------------------------------------------------------------------
# Catalogue de fournisseurs par pays — boss point 3
# ------------------------------------------------------------------

class ProviderCatalogView(APIView):
    """GET /providers/catalog/ → fournisseurs suggérés pour le pays
    du workspace (ou ?country=XX)."""

    permission_classes = [IsAuthenticated]

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
    """GET /connectors/ → connecteurs disponibles + leurs champs."""

    permission_classes = [IsAuthenticated]

    def get(self, request):
        return Response([
            {
                "slug": c.slug,
                "label": c.label,
                "description": c.description,
                "auth_fields": c.auth_fields,
            }
            for c in CONNECTORS.values()
        ])


class ConnectorSyncView(APIView):
    """POST /connectors/<slug>/sync/ {credentials:{...}}
    → appelle l'API externe et renvoie les abonnements détectés.
    Les credentials sont chiffrés et stockés pour les syncs futures."""

    permission_classes = [IsAuthenticated]

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
            label=credentials.get("label") or slug,
            defaults={
                "credentials_encrypted": crypto.encrypt(
                    json.dumps(credentials)
                ),
            },
        )
        return Response({"subscriptions": items, "count": len(items)})


class ExchangeRatesView(APIView):
    """GET /rates/?base=XAF → taux de change réels (cache 12 h).
    Permet à l'app de convertir les montants étrangers
    dans la devise locale de l'utilisateur."""

    permission_classes = [IsAuthenticated]

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


class SubscriptionBulkCreateView(APIView):
    """POST /subscriptions/bulk/ {items:[{...}]} → import en masse
    (CSV côté app ou résultat d'un connecteur)."""

    permission_classes = [IsAuthenticated]

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
        created, errors = [], []
        for i, raw in enumerate(items[:500]):
            if not raw.get("next_due_date"):
                # Import : une échéance est obligatoire — par défaut
                # dans 30 jours pour ne pas bloquer l'utilisateur.
                from datetime import date, timedelta
                raw = {**raw,
                       "next_due_date": (
                           date.today() + timedelta(days=30)
                       ).isoformat()}
            serializer = SubscriptionSerializer(data=raw)
            if serializer.is_valid():
                serializer.save(
                    owner=request.user, workspace=profile.workspace
                )
                created.append(serializer.data)
            else:
                errors.append({"index": i, "errors": serializer.errors})
        return Response(
            {"created": len(created), "errors": errors},
            status=status.HTTP_201_CREATED if created
            else status.HTTP_400_BAD_REQUEST,
        )
