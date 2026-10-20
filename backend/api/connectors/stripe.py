"""Connecteur Stripe — API REST officielle.
https://docs.stripe.com/api — clé secrète sk_live_… / sk_test_…
Récupère les abonnements actifs avec montants réels.
"""
from __future__ import annotations

import base64
import json
import time
import urllib.request


class StripeConnector:
    slug = "stripe"
    label = "Stripe"
    description = (
        "Abonnements Stripe actifs (clients facturés). "
        "Dashboard → Developers → API keys → Secret key."
    )
    auth_fields = [
        {"key": "secret_key", "label": "Clé secrète (sk_…)", "secret": True},
    ]

    _BASE = "https://api.stripe.com/v1"

    def _get(self, key: str, path: str):
        req = urllib.request.Request(
            f"{self._BASE}{path}",
            headers={
                "Authorization": "Basic "
                + base64.b64encode(f"{key}:".encode()).decode()
            },
        )
        with urllib.request.urlopen(req, timeout=15) as r:
            return json.loads(r.read().decode() or "{}")

    def fetch(self, credentials: dict) -> list[dict]:
        key = credentials["secret_key"]
        data = self._get(key, "/subscriptions?status=active&limit=50")
        out = []
        for sub in data.get("data", []):
            items = sub.get("items", {}).get("data", [])
            amount = sum(
                (i.get("price", {}).get("unit_amount") or 0)
                * (i.get("quantity") or 1)
                for i in items
            ) / 100
            price = items[0].get("price", {}) if items else {}
            interval = (price.get("recurring") or {}).get("interval", "month")
            product_id = price.get("product")
            name = f"Abonnement {product_id}" if product_id else "Abonnement Stripe"
            # current_period_end = prochaine date de facturation réelle.
            period_end = sub.get("current_period_end")
            next_due = (
                time.strftime("%Y-%m-%d", time.gmtime(period_end))
                if period_end else None
            )
            start = (
                time.strftime("%Y-%m-%d", time.gmtime(sub["start_date"]))
                if sub.get("start_date") else None
            )
            out.append({
                "name": name,
                "provider": "Stripe",
                "category": "software",
                "amount": round(amount, 2),
                "currency": (price.get("currency") or "usd").upper(),
                "cycle": {
                    "month": "monthly",
                    "year": "yearly",
                    "week": "monthly",
                }.get(interval, "monthly"),
                "next_due_date": next_due,
                "start_date": start,
            })
        return out
