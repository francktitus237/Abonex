from django.contrib.auth.models import User
from rest_framework import serializers

from .models import Payment, Subscription


class UserSerializer(serializers.ModelSerializer):
    """Forme exacte attendue par l'app Flutter :
    {id, email, role, first_name, last_name}."""

    id = serializers.CharField(read_only=True)
    role = serializers.CharField(source="profile.role")

    class Meta:
        model = User
        fields = ["id", "email", "role", "first_name", "last_name"]
        read_only_fields = ["id", "email", "first_name", "last_name"]

    def update(self, instance, validated_data):
        role = validated_data.get("profile", {}).get("role")
        if role is not None:
            instance.profile.role = role
            instance.profile.save(update_fields=["role"])
        return instance


class SubscriptionSerializer(serializers.ModelSerializer):
    class Meta:
        model = Subscription
        fields = [
            "id",
            "name",
            "provider",
            "category",
            "amount",
            "currency",
            "start_date",
            "next_due_date",
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
