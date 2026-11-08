"""Permissions DRF — module séparé de views.py : les classes
référencées dans REST_FRAMEWORK (settings) sont importées pendant
l'initialisation de DRF, ce qui interdit tout module important
rest_framework.views lui-même (import circulaire)."""
from rest_framework.permissions import SAFE_METHODS, BasePermission


class HasProfile(BasePermission):
    """Tout utilisateur fonctionnel est rattaché à un espace de
    travail. Un compte orphelin (créé via l'admin ou createsuperuser)
    obtient un 403 clair plutôt qu'un 500 au premier `user.profile`."""

    message = "Compte sans espace de travail associé."

    def has_permission(self, request, view):
        return hasattr(request.user, "profile")


class IsOwner(BasePermission):
    def has_permission(self, request, view):
        profile = getattr(request.user, "profile", None)
        return bool(profile and profile.role == "owner")


class EmployeePermission(BasePermission):
    """Salaires confidentiels : employés et leur paie réservés au
    propriétaire — un Lecteur/Assistant ne doit jamais lister les
    salaires (étude §4.1). Le rôle « manager » gère les employés
    sans voir les montants ? Non : la doc réserve aux owner +
    RH — manager exclus côté salaire, conservé sur écriture."""

    message = "Salaires réservés au propriétaire de l'espace."

    def has_permission(self, request, view):
        profile = getattr(request.user, "profile", None)
        if not profile:
            return False
        if profile.role == "owner":
            return True
        # Écriture RH déléguée possible au manager — jamais le
        # salaire en lecture ni le montant dans le payload.
        if profile.role == "manager":
            if request.method in SAFE_METHODS:
                return True
            if request.method == "POST":
                return True
            return False  # PATCH/DELETE : owner seulement
        return False


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


class IsOwnerOrManager(BasePermission):
    """Owner + manager — gouvernance (paie, budgets, verdicts)."""

    def has_permission(self, request, view):
        profile = getattr(request.user, "profile", None)
        return (
            profile is not None
            and profile.role in {"owner", "manager"}
        )
