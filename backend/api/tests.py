import os
from datetime import date
from decimal import Decimal
from io import StringIO
from unittest.mock import patch

from django.core.management import call_command
from django.core.management.base import CommandError

from django.contrib.auth.models import User
from rest_framework import status
from rest_framework.test import APITestCase

from .models import Payment, Profile, Subscription, Workspace


class WorkspaceIsolationTests(APITestCase):
    def setUp(self):
        self.workspace = Workspace.objects.create(name="Entreprise A")
        self.other_workspace = Workspace.objects.create(name="Entreprise B")
        self.owner = User.objects.create_user("owner-a", email="owner-a@example.com")
        self.member = User.objects.create_user("member-a", email="member-a@example.com")
        self.other_owner = User.objects.create_user("owner-b", email="owner-b@example.com")
        Profile.objects.create(user=self.owner, workspace=self.workspace, role="owner")
        Profile.objects.create(user=self.member, workspace=self.workspace, role="viewer")
        Profile.objects.create(
            user=self.other_owner,
            workspace=self.other_workspace,
            role="owner",
        )
        self.client.force_authenticate(self.owner)

    def test_budget_is_shared_only_with_own_workspace(self):
        response = self.client.patch(
            "/api/v1/workspace/budget/", {"monthly_budget": "1500000.00"}, format="json",
        )
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.other_workspace.refresh_from_db()
        self.assertIsNone(self.other_workspace.monthly_budget)
        self.client.force_authenticate(self.member)
        response = self.client.get("/api/v1/workspace/budget/")
        self.assertEqual(response.data["monthly_budget"], "1500000.00")
        response = self.client.patch(
            "/api/v1/workspace/budget/", {"monthly_budget": "0"}, format="json",
        )
        self.assertEqual(response.status_code, status.HTTP_403_FORBIDDEN)

    def test_budget_rejects_negative_amount(self):
        response = self.client.patch(
            "/api/v1/workspace/budget/", {"monthly_budget": "-1"}, format="json",
        )
        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)

    def test_owner_only_lists_users_from_own_workspace(self):
        response = self.client.get("/api/v1/users/")

        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(
            {item["email"] for item in response.data},
            {"owner-a@example.com", "member-a@example.com"},
        )

    def test_owner_cannot_change_user_from_another_workspace(self):
        response = self.client.patch(
            f"/api/v1/users/{self.other_owner.id}/",
            {"role": "viewer"},
            format="json",
        )

        self.assertEqual(response.status_code, status.HTTP_404_NOT_FOUND)
        self.other_owner.profile.refresh_from_db()
        self.assertEqual(self.other_owner.profile.role, "owner")

    def test_owner_can_change_member_role_but_not_own_role(self):
        response = self.client.patch(
            f"/api/v1/users/{self.member.id}/",
            {"role": "manager"},
            format="json",
        )
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.member.profile.refresh_from_db()
        self.assertEqual(self.member.profile.role, "manager")

        response = self.client.patch(
            f"/api/v1/users/{self.owner.id}/",
            {"role": "viewer"},
            format="json",
        )
        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)

    def test_payment_history_is_limited_to_workspace(self):
        subscription = Subscription.objects.create(
            owner=self.owner,
            workspace=self.workspace,
            name="Cloud",
            amount=1000,
            next_due_date=date.today(),
        )
        other_subscription = Subscription.objects.create(
            owner=self.other_owner,
            workspace=self.other_workspace,
            name="Secret",
            amount=9000,
            next_due_date=date.today(),
        )
        Payment.objects.create(
            subscription=subscription,
            workspace=self.workspace,
            recorded_by=self.owner,
            amount=1000,
            due_date=date.today(),
        )
        Payment.objects.create(
            subscription=other_subscription,
            workspace=self.other_workspace,
            recorded_by=self.other_owner,
            amount=9000,
            due_date=date.today(),
        )

        response = self.client.get(
            f"/api/v1/subscriptions/{subscription.id}/history/"
        )
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(len(response.data), 1)
        self.assertEqual(response.data[0]["amount"], "1000.00")

        response = self.client.get(
            f"/api/v1/subscriptions/{other_subscription.id}/history/"
        )
        self.assertEqual(response.status_code, status.HTTP_404_NOT_FOUND)


class RegionalDemoTests(APITestCase):
    def seed(self):
        with patch.dict(os.environ, {"DEMO_SEED_PASSWORD": "Test-only-password-123!"}):
            call_command("seed", regional_demo=True, stdout=StringIO())

    def test_seed_creates_two_isolated_regional_demos(self):
        self.seed()
        for country, currency, budget in [("cm", "XAF", 1500000), ("fr", "EUR", 6000)]:
            user = User.objects.get(username=f"demo.{country}@abonex.app")
            self.assertFalse(user.is_staff)
            self.assertTrue(user.check_password("Test-only-password-123!"))
            workspace = user.profile.workspace
            self.assertEqual(workspace.country, country.upper())
            self.assertEqual(workspace.default_currency, currency)
            self.assertEqual(workspace.monthly_budget, Decimal(budget))
            self.assertIsNotNone(workspace.demo_seeded_at)
            self.assertEqual(workspace.subscriptions.count(), 13)
            self.assertEqual(workspace.subscriptions.filter(category="event", cycle="once").count(), 3)
            self.assertEqual(workspace.payments.count(), 2)
            self.assertTrue(workspace.subscriptions.filter(status="overdue").exists())
            self.client.force_authenticate(user)
            response = self.client.get("/api/v1/subscriptions/")
            self.assertEqual(response.status_code, 200)
            self.assertEqual(len(response.data), 13)
            self.assertEqual({s["currency"] for s in response.data}, {currency})

    def test_redeploy_preserves_edits_deletions_and_passwords(self):
        self.seed()
        user = User.objects.get(username="demo.cm@abonex.app")
        user.set_password("Changed-password-456!")
        user.save()
        workspace = user.profile.workspace
        workspace.monthly_budget = 2000000
        workspace.save()
        sub = workspace.subscriptions.first()
        sub.name = "Modifié par le boss"
        sub.amount = 123
        sub.save()
        workspace.subscriptions.filter(category="event").first().delete()
        self.seed()
        self.assertEqual(workspace.subscriptions.count(), 12)
        self.assertEqual(Payment.objects.count(), 4)
        sub.refresh_from_db()
        workspace.refresh_from_db()
        user.refresh_from_db()
        self.assertEqual(sub.name, "Modifié par le boss")
        self.assertEqual(sub.amount, 123)
        self.assertEqual(workspace.monthly_budget, 2000000)
        self.assertTrue(user.check_password("Changed-password-456!"))

    def test_seed_preserves_existing_demo_workspace_and_data(self):
        user = User.objects.create_user("demo.cm@abonex.app", password="Existing-password-123!")
        workspace = Workspace.objects.create(name="Déjà en ligne", country="CM", default_currency="XAF", monthly_budget=42)
        Profile.objects.create(user=user, workspace=workspace, role="owner")
        existing = Subscription.objects.create(
            owner=user, workspace=workspace, name="Eau — résidence",
            amount=99, currency="XAF", next_due_date=date.today(),
        )
        self.seed()
        user.refresh_from_db()
        workspace.refresh_from_db()
        existing.refresh_from_db()
        self.assertEqual(user.profile.workspace_id, workspace.pk)
        self.assertEqual(workspace.monthly_budget, 42)
        self.assertEqual(existing.amount, 99)
        self.assertEqual(workspace.subscriptions.count(), 13)
        self.assertTrue(user.check_password("Existing-password-123!"))

    def test_missing_password_still_rejects_account_creation(self):
        with patch.dict(os.environ, {"DEMO_SEED_PASSWORD": ""}):
            with self.assertRaises(CommandError):
                call_command("seed", regional_demo=True, stdout=StringIO())
        self.assertEqual(User.objects.count(), 0)

    def test_wrong_country_and_currency_are_reported_without_overwriting(self):
        user = User.objects.create_user("demo.cm@abonex.app")
        workspace = Workspace.objects.create(name="Existant", country="FR", default_currency="EUR")
        Profile.objects.create(user=user, workspace=workspace, role="owner")
        errors = StringIO()
        with patch.dict(os.environ, {"DEMO_SEED_PASSWORD": "Test-only-password-123!"}):
            call_command("seed", regional_demo=True, stdout=StringIO(), stderr=errors)
        workspace.refresh_from_db()
        self.assertEqual(workspace.country, "FR")
        self.assertEqual(workspace.default_currency, "EUR")
        self.assertEqual(workspace.subscriptions.count(), 0)
        self.assertIsNone(workspace.demo_seeded_at)
        self.assertIn("pays FR, attendu CM", errors.getvalue())
        self.assertIn("devise EUR, attendue XAF", errors.getvalue())

    def test_shared_workspace_is_not_seeded(self):
        user = User.objects.create_user("demo.cm@abonex.app")
        workspace = Workspace.objects.create(name="Espace partagé", country="CM")
        Profile.objects.create(user=user, workspace=workspace, role="owner")
        member = User.objects.create_user("someone-else")
        Profile.objects.create(user=member, workspace=workspace, role="viewer")
        errors = StringIO()
        with patch.dict(os.environ, {"DEMO_SEED_PASSWORD": "Test-only-password-123!"}):
            call_command("seed", regional_demo=True, stdout=StringIO(), stderr=errors)
        self.assertEqual(workspace.subscriptions.count(), 0)
        workspace.refresh_from_db()
        self.assertIsNone(workspace.demo_seeded_at)
        self.assertIn("espace partagé", errors.getvalue())
        self.assertEqual(User.objects.get(username="demo.fr@abonex.app").profile.workspace.subscriptions.count(), 13)
