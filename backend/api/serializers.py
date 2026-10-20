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
    class Meta:
        model = Subscription
        fields = [
            "id",
            "name",
            "provider",
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
        read_only_fields = ["id"]


class PaymentSerializer(serializers.ModelSerializer):
    class Meta:
        model = Payment
        fields = ["id", "amount", "due_date", "paid_at"]
        read_only_fields = fields
