from django.contrib.auth.models import User
from rest_framework import serializers

from .models import (
    Attachment, Budget, Department, Employee, Payment,
    PayrollItem, Subscription, Supplier, Webhook, Workspace,
)


class WorkspaceSerializer(serializers.ModelSerializer):
    id = serializers.CharField(read_only=True)

    class Meta:
        model = Workspace
        fields = [
            "id", "name", "kind", "country", "default_currency",
            "extra_currencies", "configured",
        ]
        read_only_fields = ["id", "name"]


class WorkspaceBudgetSerializer(serializers.ModelSerializer):
    monthly_budget = serializers.DecimalField(
        max_digits=14, decimal_places=2, min_value=0, allow_null=True,
    )

    class Meta:
        model = Workspace
        fields = [
            "name", "kind", "country", "default_currency",
            "extra_currencies", "configured", "monthly_budget",
            "legal_name", "tax_id", "sector", "size",
            "approval_threshold",
        ]
        read_only_fields = ["kind", "configured"]


class UserSerializer(serializers.ModelSerializer):
    """Forme exacte attendue par l'app Flutter :
    {id, email, role, first_name, last_name, language, workspace}."""

    id = serializers.CharField(read_only=True)
    role = serializers.CharField(source="profile.role")
    language = serializers.CharField(source="profile.language")
    workspace = WorkspaceSerializer(source="profile.workspace")
    avatar_url = serializers.SerializerMethodField()

    class Meta:
        model = User
        fields = [
            "id", "email", "role", "first_name", "last_name",
            "language", "workspace", "avatar_url",
        ]
        read_only_fields = [
            "id", "email", "first_name", "last_name", "workspace",
            "avatar_url",
        ]

    def get_avatar_url(self, obj):
        """URL absolue de la photo — le mobile l'affiche telle
        quelle (aucune recomposition de domaine à faire côté app).
        Un utilisateur sans Profile (compte créé hors app) ne doit
        pas lever RelatedObjectDoesNotExist → 500."""
        avatar = getattr(getattr(obj, "profile", None), "avatar", None)
        if not avatar:
            return None
        request = self.context.get("request")
        return (
            request.build_absolute_uri(avatar.url)
            if request is not None
            else avatar.url
        )

    def update(self, instance, validated_data):
        profile_data = validated_data.get("profile", {})
        role = profile_data.get("role")
        if role is not None:
            instance.profile.role = role
        language = profile_data.get("language")
        if language is not None:
            instance.profile.language = language
        if role is not None or language is not None:
            instance.profile.save()
        return instance


class SubscriptionSerializer(serializers.ModelSerializer):
    provider_country = serializers.SerializerMethodField()
    provider_flag = serializers.SerializerMethodField()
    country_flag = serializers.SerializerMethodField()

    class Meta:
        model = Subscription
        fields = [
            "id",
            "name",
            "provider",
            "provider_country",
            "provider_flag",
            "country",
            "country_flag",
            "description",
            "category",
            "amount",
            "currency",
            "start_date",
            "next_due_date",
            "due_time",
            "end_date",
            "cycle",
            "status",
            "is_shared",
            "payment_url",
            "department",
            "assignee",
            "notice_period_days",
        ]
        read_only_fields = [
            "id", "provider_country", "provider_flag", "country_flag",
        ]

    def _provider_origin(self, obj):
        from .catalog import provider_origin

        return provider_origin(obj.provider) or provider_origin(obj.name)

    def get_provider_country(self, obj):
        return self._provider_origin(obj) or ""

    def get_provider_flag(self, obj):
        from .catalog import flag_emoji

        return flag_emoji(self._provider_origin(obj))

    def get_country_flag(self, obj):
        from .catalog import flag_emoji

        # Pays choisi par l'utilisateur ; à défaut celui du workspace.
        return flag_emoji(obj.country or obj.workspace.country)

    def to_representation(self, instance):
        data = super().to_representation(instance)
        # Les anciens enregistrements n'ont pas de pays : on sert
        # celui du workspace pour que l'app ait toujours un drapeau.
        if not data.get("country"):
            data["country"] = instance.workspace.country or ""
        return data


class DepartmentSerializer(serializers.ModelSerializer):
    class Meta:
        model = Department
        fields = ["id", "name", "manager", "created_at"]
        read_only_fields = ["id", "created_at"]


class BudgetSerializer(serializers.ModelSerializer):
    """Budget par catégorie OU par département — exactement
    l'un des deux champs doit être renseigné."""

    class Meta:
        model = Budget
        fields = [
            "id", "department", "category", "amount",
            "alert_threshold", "created_at",
        ]
        read_only_fields = ["id", "created_at"]

    def validate(self, attrs):
        department = attrs.get("department")
        category = attrs.get("category", "")
        if bool(department) == bool(category):
            raise serializers.ValidationError(
                "Renseignez un département OU une catégorie."
            )
        return attrs


class AttachmentSerializer(serializers.ModelSerializer):
    """Justificatif — file_url absolu (comme avatar_url) pour que
    l'app ouvre le document sans reconstruire l'URL."""

    file_url = serializers.SerializerMethodField()

    class Meta:
        model = Attachment
        fields = [
            "id", "subscription", "payment", "name", "file",
            "file_url", "uploaded_by", "created_at",
        ]
        read_only_fields = ["id", "file_url", "uploaded_by", "created_at"]

    def get_file_url(self, obj):
        request = self.context.get("request")
        return (
            request.build_absolute_uri(obj.file.url)
            if request is not None
            else obj.file.url
        )


class WebhookSerializer(serializers.ModelSerializer):
    """Webhook sortant (étude Phase 4)."""

    class Meta:
        model = Webhook
        fields = [
            "id", "url", "secret", "events", "active",
            "created_at",
        ]
        read_only_fields = ["id", "created_at"]


class SupplierSerializer(serializers.ModelSerializer):
    """Fournisseur/contrat (étude §E1)."""

    class Meta:
        model = Supplier
        fields = [
            "id", "name", "contact", "phone", "email",
            "payment_method", "payment_terms_days",
            "notice_period_days", "notes", "created_at",
        ]
        read_only_fields = ["id", "created_at"]


class PayrollItemSerializer(serializers.ModelSerializer):
    """Élément de paie — prime, avance, retenue, heures supp."""

    class Meta:
        model = PayrollItem
        fields = [
            "id", "employee", "kind", "label", "amount",
            "period", "created_at",
        ]
        read_only_fields = ["id", "created_at"]


class EmployeeSerializer(serializers.ModelSerializer):
    """Employé d'un espace entreprise — l'abonnement payroll
    généré n'est PAS exposé ici, il vit dans /subscriptions/."""

    class Meta:
        model = Employee
        fields = [
            "id", "name", "position", "salary", "currency",
            "pay_day", "active", "created_at",
            "hire_date", "contract", "department", "payment_info",
            "user",
        ]
        read_only_fields = ["id", "created_at"]


class PaymentSerializer(serializers.ModelSerializer):
    class Meta:
        model = Payment
        fields = [
            "id", "amount", "amount_paid", "method", "reference",
            "status", "approved_by", "rejection_reason",
            "due_date", "paid_at",
        ]
        read_only_fields = fields
