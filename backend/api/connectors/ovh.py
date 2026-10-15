"""Connecteur OVH — API officielle (https://api.ovh.com).

L'utilisateur crée ses clés sur https://api.ovh.com/createToken/
(3 clés : application key, application secret, consumer key).
On interroge /me et les services pour proposer les abonnements.
"""
from __future__ import annotations

import hashlib
import time
import urllib.request
import json


class OvhConnector:
    slug = "ovh"
    label = "OVHcloud"
    description = (
        "Serveurs dédiés, VPS, cloud et domaines OVH. "
        "Créez vos clés sur api.ovh.com/createToken puis collez-les ici."
    )
    auth_fields = [
        {"key": "app_key", "label": "Application Key", "secret": True},
        {"key": "app_secret", "label": "Application Secret", "secret": True},
        {"key": "consumer_key", "label": "Consumer Key", "secret": True},
        {"key": "endpoint", "label": "Endpoint (ovh-eu / ovh-ca)",
         "secret": False, "default": "ovh-eu"},
    ]

    _BASE = {
        "ovh-eu": "https://eu.api.ovh.com/1.0",
        "ovh-ca": "https://ca.api.ovh.com/1.0",
    }

    def _timestamp(self, base: str) -> int:
        with urllib.request.urlopen(f"{base}/auth/time", timeout=10) as r:
            return int(r.read().decode())

    def _call(self, creds: dict, method: str, path: str, body: str = ""):
        base = self._BASE.get(creds.get("endpoint") or "ovh-eu",
                              self._BASE["ovh-eu"])
        ts = self._timestamp(base)
        url = f"{base}{path}"
        sig = "$1$" + hashlib.sha1(
            "+".join([
                creds["app_secret"],
                creds["consumer_key"],
                method,
                url,
                body,
                str(ts),
            ]).encode()
        ).hexdigest()
        req = urllib.request.Request(
            url,
            data=body.encode() if body else None,
            method=method,
            headers={
                "X-Ovh-Application": creds["app_key"],
                "X-Ovh-Consumer": creds["consumer_key"],
                "X-Ovh-Signature": sig,
                "X-Ovh-Timestamp": str(ts),
                "Content-Type": "application/json",
            },
        )
        with urllib.request.urlopen(req, timeout=15) as r:
            return json.loads(r.read().decode() or "null")

    def fetch(self, credentials: dict) -> list[dict]:
        """Retourne les services OVH normalisés en abonnements."""
        services = self._call(credentials, "GET", "/me/service") or []
        now = int(time.time())
        out = []
        for svc in services[:100]:
            svc_id = svc.get("serviceId") or svc.get("id")
            try:
                detail = self._call(
                    credentials, "GET", f"/me/service/{svc_id}"
                )
            except Exception:
                continue
            billing = detail.get("billing", {})
            next_due = (billing.get("nextBillingDate")
                        or billing.get("expirationDate")
                        or "")
            plan = (billing.get("plan") or {}).get("code") or ""
            renew = billing.get("renew") or {}
            cycle = "monthly"
            if renew.get("period") in ("P1Y", "P12M"):
                cycle = "yearly"
            out.append({
                "name": detail.get("displayName")
                        or svc.get("serviceId") or "Service OVH",
                "provider": "OVHcloud",
                "category": "software",
                "amount": 0,  # le prix n'est pas dans /me/service
                "currency": "EUR",
                "cycle": cycle,
                "next_due_date": next_due[:10] if next_due else None,
                "start_date": (detail.get("creation") or "")[:10] or None,
            })
        return out
