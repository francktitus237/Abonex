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


def has_cap(profile, cap):
    """Capacité métier (étude Phase 4 — rôles personnalisés) :
    owner/manager → toujours True ; viewer/assistant → True si
    le Membership actif porte `cap` dans custom_permissions."""
    if profile is None:
        return False
    if profile.role in {"owner", "manager"}:
        return True
    from .models import Membership

    extra = (
        Membership.objects.filter(
            user=profile.user,
            workspace=profile.workspace,
            status="active",
        )
        .values_list("custom_permissions", flat=True)
        .first()
        or ""
    )
    return cap in extra.split(",")


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
        # Rôle personnalisé : capacité « employees » accordée
        # par le propriétaire (lecture seule — les montants
        # restent masqués côté serializer).
        if request.method in SAFE_METHODS and has_cap(
            profile, "employees"
        ):
            return True
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
    """Owner + manager — gouvernance (paie, budgets, verdicts) ;
    un rôle personnalisé passe si la vue déclare `required_cap`
    (ex. payments, budgets) présent dans custom_permissions."""

    def has_permission(self, request, view):
        profile = getattr(request.user, "profile", None)
        if profile is None:
            return False
        if profile.role in {"owner", "manager"}:
            return True
        cap = getattr(view, "required_cap", None)
        return cap is not None and has_cap(profile, cap)
