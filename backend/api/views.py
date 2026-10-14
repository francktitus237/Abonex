from django.contrib.auth import authenticate
from django.contrib.auth.models import User
from django.shortcuts import get_object_or_404
from rest_framework import generics, status
from rest_framework.permissions import SAFE_METHODS, AllowAny, BasePermission, IsAuthenticated
from rest_framework.response import Response
from rest_framework.views import APIView
from rest_framework_simplejwt.tokens import RefreshToken

from .models import Payment, Profile, Subscription, Workspace
from .serializers import PaymentSerializer, SubscriptionSerializer, UserSerializer


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
