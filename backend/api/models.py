from django.contrib.auth.models import User
from django.db import models

ROLES = [
    ("owner", "Propriétaire"),
    ("manager", "Gestionnaire"),
    ("assistant", "Assistant"),
    ("viewer", "Lecteur"),
]


class Workspace(models.Model):
    KINDS = [
        ("personal", "Personnel"),
        ("business", "Entreprise"),
    ]

    name = models.CharField(max_length=120)
    # Type de compte : personnel (usage individuel) ou
    # entreprise (espace de travail + employés + rôles).
    kind = models.CharField(
        max_length=16, choices=KINDS, default="personal"
    )
    # Configuration de premier démarrage : pays + devises.
    country = models.CharField(max_length=2, blank=True, default="")
    default_currency = models.CharField(max_length=8, blank=True, default="")
    # Devises secondaires affichées dans l'app (max 2-3).
    extra_currencies = models.JSONField(default=list, blank=True)
    configured = models.BooleanField(default=False)
    monthly_budget = models.DecimalField(max_digits=14, decimal_places=2, null=True, blank=True)
    demo_seeded_at = models.DateTimeField(null=True, blank=True)
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
    language = models.CharField(max_length=8, blank=True, default="fr")
    # Photo de profil uploadée par l'utilisateur (FileField :
    # aucune dépendance Pillow — validation type/taille à la vue).
    avatar = models.FileField(upload_to="avatars/", blank=True)
    # Adresse confirmée par lien email (anti-comptes bidons).
    email_verified = models.BooleanField(default=False)
    # Jeton FCM du dernier appareil connecté — notifications push.
    fcm_token = models.CharField(max_length=255, blank=True, default="")


class Invitation(models.Model):
    """Invitation email → rôle dans un espace de travail.
    Le destinataire confirme en créant son compte via le token."""

    STATUSES = [("pending", "En attente"), ("accepted", "Acceptée")]

    workspace = models.ForeignKey(
        Workspace, on_delete=models.CASCADE, related_name="invitations"
    )
    email = models.EmailField()
    role = models.CharField(max_length=16, choices=ROLES, default="viewer")
    token = models.CharField(max_length=64, unique=True)
    invited_by = models.ForeignKey(
        User, on_delete=models.SET_NULL, null=True, related_name="invitations"
    )
    status = models.CharField(
        max_length=16, choices=STATUSES, default="pending"
    )
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        unique_together = [("workspace", "email")]


class ProviderConnection(models.Model):
    """Compte externe connecté (OVH, IONOS…).
    Les secrets sont chiffrés (Fernet) avant stockage."""

    workspace = models.ForeignKey(
        Workspace, on_delete=models.CASCADE, related_name="connections"
    )
    provider = models.CharField(max_length=40)  # ex. "ovh", "ionos"
    label = models.CharField(max_length=120, blank=True)
    credentials_encrypted = models.TextField(blank=True)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        unique_together = [("workspace", "provider", "label")]


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
        # Récurrences courtes — pensées surtout pour les
        # rendez-vous récurrents (même heure chaque jour/semaine).
        ("daily", "Quotidien"),
        ("weekly", "Hebdomadaire"),
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
    # Note libre : ville/lieu du service, référence contrat…
    # Affichée dans les rappels et notifications.
    description = models.CharField(max_length=255, blank=True)
    # Pays où l'abonnement est actif (ISO alpha-2) — choisi par
    # l'utilisateur, indépendant du pays d'origine du fournisseur.
    country = models.CharField(max_length=2, blank=True, default="")
    category = models.CharField(
        max_length=16, choices=CATEGORIES, default="other"
    )
    amount = models.DecimalField(max_digits=14, decimal_places=2)
    currency = models.CharField(max_length=8, default="XAF")
    # Date de souscription/première échéance — peut être inconnue
    # ou dans le passé (saisie rétroactive).
    start_date = models.DateField(null=True, blank=True)
    next_due_date = models.DateField()
    # Heure de l'échéance — renseignée pour les rendez-vous/événements.
    due_time = models.TimeField(null=True, blank=True)
    # Date de fin de contrat — null = renouvellement sans fin.
    end_date = models.DateField(null=True, blank=True)
    # Abonnement du foyer : charge partagée par la famille
    # (Netflix famille, box internet…). Déduit du budget du foyer.
    is_shared = models.BooleanField(default=False)
    # Lien de paiement direct (portail client, page marchande…) —
    # bouton « Payer » dans le détail de l'abonnement.
    payment_url = models.URLField(max_length=500, blank=True, default="")
    cycle = models.CharField(max_length=16, choices=CYCLES, default="monthly")
    status = models.CharField(
        max_length=16, choices=STATUSES, default="dueSoon"
    )
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ["next_due_date"]


class Employee(models.Model):
    """Employé d'un espace entreprise. Sa paie génère un
    abonnement 'payroll' mensuel suivi comme les autres
    échéances — visible au dashboard, calendrier, rappels."""

    workspace = models.ForeignKey(
        Workspace, on_delete=models.CASCADE, related_name="employees"
    )
    name = models.CharField(max_length=120)
    # Poste / fonction — rappelé dans la description de l'échéance.
    position = models.CharField(max_length=120, blank=True)
    salary = models.DecimalField(max_digits=14, decimal_places=2)
    currency = models.CharField(max_length=8, default="XAF")
    # Jour de paie mensuel (1-31, clampé sur les mois courts).
    pay_day = models.PositiveSmallIntegerField(default=25)
    active = models.BooleanField(default=True)
    # Abonnement payroll généré — null si l'employé est inactif.
    subscription = models.OneToOneField(
        Subscription,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name="employee",
    )
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ["name"]


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
