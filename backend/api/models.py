from django.contrib.auth.models import User
from django.db import models

ROLES = [
    ("owner", "Propriétaire"),
    ("manager", "Gestionnaire"),
    ("assistant", "Assistant"),
    ("viewer", "Lecteur"),
]


class Workspace(models.Model):
    name = models.CharField(max_length=120)
    created_at = models.DateTimeField(auto_now_add=True)


class Profile(models.Model):
    """Rôle métier attaché à l'utilisateur Django."""

    user = models.OneToOneField(
        User, on_delete=models.CASCADE, related_name="profile"
    )
    workspace = models.ForeignKey(
        Workspace, on_delete=models.CASCADE, related_name="profiles"
    )
    role = models.CharField(max_length=16, choices=ROLES, default="viewer")


class Subscription(models.Model):
    """Échéance récurrente suivie par l'app Abonex."""

    CATEGORIES = [
        ("software", "Logiciels"),
        ("rent", "Loyers"),
        ("insurance", "Assurances"),
        ("telecom", "Télécom"),
        ("energy", "Énergie"),
        ("water", "Eau"),
        ("payroll", "Salaires"),
        ("transport", "Transport"),
        ("event", "Événement"),
        ("other", "Autre"),
    ]
    CYCLES = [
        ("monthly", "Mensuel"),
        ("quarterly", "Trimestriel"),
        ("yearly", "Annuel"),
        # Paiement/événement ponctuel (rendez-vous, facture unique).
        ("once", "Une seule fois"),
    ]
    STATUSES = [
        ("paid", "Payé"),
        ("dueSoon", "À venir"),
        ("overdue", "En retard"),
    ]

    owner = models.ForeignKey(
        User, on_delete=models.CASCADE, related_name="subscriptions"
    )
    workspace = models.ForeignKey(
        Workspace, on_delete=models.CASCADE, related_name="subscriptions"
    )
    name = models.CharField(max_length=120)
    provider = models.CharField(max_length=120, blank=True)
    category = models.CharField(
        max_length=16, choices=CATEGORIES, default="other"
    )
    amount = models.DecimalField(max_digits=14, decimal_places=2)
    currency = models.CharField(max_length=8, default="XAF")
    # Date de souscription/première échéance — peut être inconnue
    # ou dans le passé (saisie rétroactive).
    start_date = models.DateField(null=True, blank=True)
    next_due_date = models.DateField()
    # Date de fin de contrat — null = renouvellement sans fin.
    end_date = models.DateField(null=True, blank=True)
    cycle = models.CharField(max_length=16, choices=CYCLES, default="monthly")
    status = models.CharField(
        max_length=16, choices=STATUSES, default="dueSoon"
    )
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ["next_due_date"]


class Payment(models.Model):
    subscription = models.ForeignKey(
        Subscription, on_delete=models.CASCADE, related_name="payments"
    )
    workspace = models.ForeignKey(
        Workspace, on_delete=models.CASCADE, related_name="payments"
    )
    recorded_by = models.ForeignKey(
        User, on_delete=models.SET_NULL, null=True, related_name="recorded_payments"
    )
    amount = models.DecimalField(max_digits=14, decimal_places=2)
    due_date = models.DateField()
    paid_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ["-paid_at"]
