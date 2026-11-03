from django.contrib.auth.models import User
from rest_framework import serializers

from .models import Payment, Subscription, Workspace


class WorkspaceSerializer(serializers.ModelSerializer):
    id = serializers.CharField(read_only=True)

    class Meta:
        model = Workspace
        fields = [
            "id", "name", "country", "default_currency",
            "extra_currencies", "configured",
        ]
        read_only_fields = ["id", "name"]


class WorkspaceBudgetSerializer(serializers.ModelSerializer):
    monthly_budget = serializers.DecimalField(
        max_digits=14, decimal_places=2, min_value=0, allow_null=True,
    )

    class Meta:
        model = Workspace
        fields = ["monthly_budget"]


class UserSerializer(serializers.ModelSerializer):
    """Forme exacte attendue par l'app Flutter :
    {id, email, role, first_name, last_name, language, workspace}."""

    id = serializers.CharField(read_only=True)
    role = serializers.CharField(source="profile.role")
    language = serializers.CharField(source="profile.language")
    workspace = WorkspaceSerializer(source="profile.workspace")

    class Meta:
        model = User
        fields = [
            "id", "email", "role", "first_name", "last_name",
            "language", "workspace",
        ]
        read_only_fields = [
            "id", "email", "first_name", "last_name", "workspace",
        ]

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


class PaymentSerializer(serializers.ModelSerializer):
    class Meta:
        model = Payment
        fields = ["id", "amount", "due_date", "paid_at"]
        read_only_fields = fields
