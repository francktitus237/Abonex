"""Données de démo : compte propriétaire + équipe + abonnements."""
import os
from datetime import time, timedelta
from decimal import Decimal

from django.contrib.auth.models import User
from django.core.management.base import BaseCommand, CommandError
from django.db import transaction
from django.utils import timezone

from api.models import Payment, Profile, Subscription, Workspace


class Command(BaseCommand):
    help = "Crée le compte démo et un jeu de données réaliste."

    def add_arguments(self, parser):
        parser.add_argument("--regional-demo", action="store_true")

    def handle(self, *args, **kwargs):
        if kwargs["regional_demo"]:
            self.seed_regional()
            return
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

    @transaction.atomic
    def seed_regional(self):
        today = timezone.localdate()
        for country, currency, budget in [("CM", "XAF", 1500000), ("FR", "EUR", 6000)]:
            email = f"demo.{country.lower()}@abonex.app"
            owner = User.objects.filter(username=email).first()
            if owner is None:
                if User.objects.filter(email__iexact=email).exists():
                    raise CommandError(f"Compte {email} existant avec un autre identifiant : vérifier manuellement.")
                password = os.getenv("DEMO_SEED_PASSWORD", "")
                if len(password) < 12:
                    raise CommandError("DEMO_SEED_PASSWORD (12 caractères minimum) requis pour créer les comptes démo.")
                owner = User.objects.create_user(
                    username=email, email=email, password=password,
                    first_name="Démo", last_name="Cameroun" if country == "CM" else "France",
                )
            profile = Profile.objects.filter(user=owner).first()
            if profile is None:
                workspace = Workspace.objects.create(
                    name=f"Démo Abonex — {country}", country=country,
                    default_currency=currency, configured=True,
                )
                profile = Profile.objects.create(user=owner, workspace=workspace, role="owner", language="fr")
            workspace = Workspace.objects.select_for_update().get(pk=profile.workspace_id)
            if workspace.demo_seeded_at:
                self.stdout.write(f"{email} : démonstration déjà initialisée, données conservées.")
                continue
            if (profile.role != "owner" or
                    workspace.profiles.exclude(user=owner).exists() or
                    workspace.country not in ("", country) or
                    workspace.default_currency not in ("", currency)):
                raise CommandError(f"Espace de {email} incompatible : aucune donnée démo ajoutée.")
            workspace.country = country
            workspace.default_currency = currency
            workspace.configured = True
            if workspace.monthly_budget is None:
                workspace.monthly_budget = budget
            cm = country == "CM"
            rows = [
                ("Électricité — bureaux", "ENEO" if cm else "EDF", "energy", 65000 if cm else 145, -3, "monthly", "overdue"),
                ("Eau — résidence", "Camwater" if cm else "Veolia", "water", 12000 if cm else 38, 3, "monthly", "dueSoon"),
                ("Internet et téléphone", "MTN Cameroun" if cm else "Orange", "telecom", 35000 if cm else 49.99, 2, "monthly", "dueSoon"),
                ("Loyer — bureau", "Bailleur", "rent", 250000 if cm else 1200, 5, "monthly", "dueSoon"),
                ("Salaires — équipe", "Interne", "payroll", 450000 if cm else 2800, 7, "monthly", "dueSoon"),
                ("Assurance professionnelle", "AXA", "insurance", 180000 if cm else 480, 45, "yearly", "dueSoon"),
                ("Transport — forfait", "Transport local", "transport", 45000 if cm else 90, 12, "monthly", "dueSoon"),
                ("Panier alimentaire", "Commerce local", "other", 60000 if cm else 180, 4, "monthly", "dueSoon"),
                ("Outils collaboratifs", "Microsoft 365", "software", 15000 if cm else 22, 25, "monthly", "paid"),
                ("Hébergement — trimestre", "OVHcloud", "software", 30000 if cm else 45, 35, "quarterly", "paid"),
            ]
            for name, provider, category, amount, days, cycle, state in rows:
                sub, created = Subscription.objects.get_or_create(
                    workspace=workspace, name=name,
                    defaults={
                        "owner": owner, "provider": provider, "category": category,
                        "amount": Decimal(str(amount)), "currency": currency,
                        "next_due_date": today + timedelta(days=days),
                        "start_date": today - timedelta(days=60),
                        "cycle": cycle, "status": state,
                        "description": "Exemple fictif de démonstration — aucun fournisseur connecté.",
                    },
                )
                if created and state == "paid":
                    Payment.objects.create(
                        subscription=sub, workspace=workspace, recorded_by=owner,
                        amount=sub.amount, due_date=today,
                    )
            for name, days, hour in [("Rendez-vous comptable", 1, 10), ("Entretien du logement", 6, 14), ("Réunion de suivi", 15, 9)]:
                Subscription.objects.get_or_create(
                    workspace=workspace, name=name,
                    defaults={
                        "owner": owner, "category": "event", "cycle": "once",
                        "amount": 0, "currency": currency, "provider": "",
                        "next_due_date": today + timedelta(days=days),
                        "due_time": time(hour, 30), "status": "dueSoon",
                        "description": "Rendez-vous fictif de démonstration.",
                    },
                )
            workspace.demo_seeded_at = timezone.now()
            workspace.save(update_fields=["country", "default_currency", "configured", "monthly_budget", "demo_seeded_at"])
            self.stdout.write(self.style.SUCCESS(f"{email} : abonnements, rendez-vous, paiements et budget prêts."))
