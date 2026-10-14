"""Données de démo : compte propriétaire + équipe + abonnements."""
from datetime import timedelta

from django.contrib.auth.models import User
from django.core.management.base import BaseCommand
from django.utils import timezone

from api.models import Profile, Subscription, Workspace


class Command(BaseCommand):
    help = "Crée le compte démo et un jeu de données réaliste."

    def handle(self, *args, **kwargs):
        owner, created = User.objects.get_or_create(
            username="demo@abonex.app",
            defaults={
                "email": "demo@abonex.app",
                "first_name": "Alex",
                "last_name": "Mballa",
                "is_staff": True,
            },
        )
        if created:
            owner.set_password("Demo1234")
            owner.save()
        workspace, _ = Workspace.objects.get_or_create(name="Démo Abonex")
        Profile.objects.update_or_create(
            user=owner,
            defaults={"role": "owner", "workspace": workspace},
        )

        team = [
            ("sandra.ngono@abonex.app", "Sandra", "Ngono", "manager"),
            ("marc.etoundi@abonex.app", "Marc", "Etoundi", "assistant"),
            ("claire.fotso@abonex.app", "Claire", "Fotso", "viewer"),
        ]
        for email, first, last, role in team:
            user, created = User.objects.get_or_create(
                username=email,
                defaults={
                    "email": email,
                    "first_name": first,
                    "last_name": last,
                },
            )
            if created:
                user.set_password("Abonex123")
                user.save()
            Profile.objects.update_or_create(
                user=user,
                defaults={"role": role, "workspace": workspace},
            )

        now = timezone.now().date()
        subs = [
            ("Loyer siège social", "Immobilier SARL", "rent",
             850000, 4, "dueSoon", "monthly"),
            ("Google Workspace", "Google", "software",
             62400, -2, "paid", "monthly"),
            ("Assurance flotte", "AXA", "insurance",
             145000, 11, "dueSoon", "yearly"),
            ("Orange Business", "Orange", "telecom",
             48500, -6, "overdue", "monthly"),
            ("Électricité bureaux", "ENEO", "energy",
             96700, 8, "dueSoon", "monthly"),
            ("Eau bureaux", "CDE", "water",
             34200, 14, "dueSoon", "monthly"),
            ("Salaires employés", "Interne", "payroll",
             1250000, 0, "dueSoon", "monthly"),
            ("Notion Team", "Notion", "software",
             23800, 17, "paid", "monthly"),
            ("Location véhicules", "Express Union", "transport",
             210000, 23, "dueSoon", "quarterly"),
            ("Hébergement cloud", "AWS", "software",
             132000, 2, "dueSoon", "monthly"),
        ]
        for name, provider, cat, amount, days, st, cycle in subs:
            Subscription.objects.get_or_create(
                owner=owner,
                workspace=workspace,
                name=name,
                defaults={
                    "provider": provider,
                    "category": cat,
                    "amount": amount,
                    "next_due_date": now + timedelta(days=days),
                    "status": st,
                    "cycle": cycle,
                },
            )
        self.stdout.write(self.style.SUCCESS("Données de démo prêtes."))
