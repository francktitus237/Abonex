from datetime import date

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
