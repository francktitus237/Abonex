"""Connecteurs plateformes de paiement récurrent.

Récupèrent les mandats/abonnements de prélèvement : c'est souvent là
que se trouvent les VRAIES dates de renouvellement pour les services
qui n'ont pas d'API de facturation propre.

- Mollie     : https://docs.mollie.com — Dashboard → Developers → API keys
- Paddle     : https://developer.paddle.com — Paddle → Developer tools
               → Authentication → API key
- GoCardless : https://developer.gocardless.com — access token
"""
from __future__ import annotations

import json
import urllib.request


def _get_json(url: str, headers: dict):
    req = urllib.request.Request(url, headers=headers)
    with urllib.request.urlopen(req, timeout=15) as r:
        return json.loads(r.read().decode() or "{}")


class MollieConnector:
    slug = "mollie"
    label = "Mollie"
    description = (
        "Abonnements et prélèvements Mollie (clients facturés) — "
        "date du prochain paiement incluse. Dashboard Mollie → "
        "Developers → API keys → Live key."
    )
    auth_fields = [
        {"key": "api_key", "label": "Clé API (live_…)", "secret": True},
    ]

    _BASE = "https://api.mollie.com/v2"

    _CYCLES = {
        "week": "monthly",
        "month": "monthly",
        "months": "monthly",
        "quarter": "quarterly",
        "year": "yearly",
    }

    def fetch(self, credentials: dict) -> list[dict]:
        h = {"Authorization": f"Bearer {credentials['api_key']}"}
        out = []
        customers = _get_json(f"{self._BASE}/customers?limit=50", h)
        for cust in customers.get("_embedded", {}).get("customers", []):
            cid = cust.get("id")
            if not cid:
                continue
            try:
                subs = _get_json(
                    f"{self._BASE}/customers/{cid}/subscriptions?limit=50", h
                )
            except Exception:
                continue
            for s in subs.get("_embedded", {}).get("subscriptions", []):
                if s.get("status") not in ("active", "pending"):
                    continue
                amount = s.get("amount") or {}
                interval = (s.get("interval") or "month").lower()
                cycle = self._CYCLES.get(interval.split()[-1], "monthly")
                out.append({
                    "name": s.get("description")
                            or f"Abonnement {cust.get('name', 'Mollie')}",
                    "provider": "Mollie",
                    "category": "software",
                    "amount": float(amount.get("value") or 0),
                    "currency": (amount.get("currency") or "EUR").upper(),
                    "cycle": cycle,
                    "next_due_date": (s.get("nextPaymentDate")
                                      or "")[:10] or None,
                    "start_date": (s.get("startDate") or "")[:10] or None,
                })
        return out


class PaddleConnector:
    slug = "paddle"
    label = "Paddle"
    description = (
        "Abonnements Paddle Billing — prochaine date de facturation "
        "incluse. Paddle → Developer Tools → Authentication → API key."
    )
    auth_fields = [
        {"key": "api_key", "label": "Clé API", "secret": True},
        {"key": "sandbox", "label": "Environnement (live / sandbox)",
         "secret": False, "default": "live"},
    ]

    def fetch(self, credentials: dict) -> list[dict]:
        base = (
            "https://sandbox-api.paddle.com"
            if (credentials.get("sandbox") or "live") == "sandbox"
            else "https://api.paddle.com"
        )
        h = {
            "Authorization": f"Bearer {credentials['api_key']}",
        }
        data = _get_json(f"{base}/subscriptions?per_page=50", h)
        out = []
        for s in data.get("data") or []:
            if s.get("status") != "active":
                continue
            items = s.get("items") or []
            amount = 0.0
            currency = "EUR"
            cycle = "monthly"
            if items:
                price = (items[0].get("price") or {})
                unit = (price.get("unit_price") or {})
                qty = items[0].get("quantity") or 1
                amount = float(unit.get("amount") or 0) * qty / 100
                currency = (s.get("currency_code")
                            or "EUR").upper()
                interval = (price.get("billing_cycle") or {})
                if interval.get("interval") == "year":
                    cycle = "yearly"
            out.append({
                "name": (s.get("custom_data") or {}).get("name")
                        or "Abonnement Paddle",
                "provider": "Paddle",
                "category": "software",
                "amount": round(amount, 2),
                "currency": currency,
                "cycle": cycle,
                "next_due_date": (s.get("next_billed_at")
                                  or "")[:10] or None,
                "start_date": (s.get("started_at") or "")[:10] or None,
            })
        return out


class GoCardlessConnector:
    slug = "gocardless"
    label = "GoCardless"
    description = (
        "Prélèvements SEPA GoCardless. manage.gocardless.com → "
        "Developers → Access tokens."
    )
    auth_fields = [
        {"key": "access_token", "label": "Access token", "secret": True},
        {"key": "sandbox", "label": "Environnement (live / sandbox)",
         "secret": False, "default": "live"},
    ]

    _UNITS = {
        "weekly": "monthly",
        "monthly": "monthly",
        "yearly": "yearly",
    }

    def fetch(self, credentials: dict) -> list[dict]:
        base = (
            "https://api-sandbox.gocardless.com"
            if (credentials.get("sandbox") or "live") == "sandbox"
            else "https://api.gocardless.com"
        )
        data = _get_json(
            f"{base}/subscriptions?limit=100",
            headers={
                "Authorization": f"Bearer {credentials['access_token']}",
                "GoCardless-Version": "2015-07-06",
            },
        )
        out = []
        for s in data.get("subscriptions") or []:
            if s.get("status") != "active":
                continue
            out.append({
                "name": s.get("name") or "Prélèvement GoCardless",
                "provider": "GoCardless",
                "category": "software",
                "amount": float(s.get("amount") or 0) / 100,
                "currency": (s.get("currency") or "EUR").upper(),
                "cycle": self._UNITS.get(
                    s.get("interval_unit"), "monthly"
                ),
                "next_due_date": (s.get("upcoming_payments") or [{}])[0]
                                 .get("charge_date")
                                 or (s.get("start_date") or "")[:10]
                                 or None,
                "start_date": (s.get("start_date") or "")[:10] or None,
            })
        return out
