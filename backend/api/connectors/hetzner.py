"""Connecteur Hetzner Cloud — API Bearer token.
https://docs.hetzner.cloud — Hetzner Cloud Console → Security → API Tokens.
"""
from __future__ import annotations

import json
import urllib.request


class HetznerConnector:
    slug = "hetzner"
    label = "Hetzner Cloud"
    description = (
        "Serveurs cloud Hetzner. Console Cloud → projet → "
        "Security → API Tokens."
    )
    auth_fields = [
        {"key": "token", "label": "Token API", "secret": True},
    ]

    _BASE = "https://api.hetzner.cloud/v1"

    def fetch(self, credentials: dict) -> list[dict]:
        req = urllib.request.Request(
            f"{self._BASE}/servers",
            headers={"Authorization": f"Bearer {credentials['token']}"},
        )
        with urllib.request.urlopen(req, timeout=15) as r:
            data = json.loads(r.read().decode() or "{}")
        return [
            {
                "name": s.get("name") or "Serveur Hetzner",
                "provider": "Hetzner Cloud",
                "category": "software",
                "amount": 0,
                "currency": "EUR",
                "cycle": "monthly",
                "next_due_date": None,
                "start_date": (s.get("created") or "")[:10] or None,
            }
            for s in data.get("servers", [])
        ]


class DigitalOceanConnector:
    slug = "digitalocean"
    label = "DigitalOcean"
    description = (
        "Droplets DigitalOcean. Cloud Console → API → "
        "Personal Access Token."
    )
    auth_fields = [
        {"key": "token", "label": "Token API", "secret": True},
    ]

    _BASE = "https://api.digitalocean.com/v2"

    def fetch(self, credentials: dict) -> list[dict]:
        req = urllib.request.Request(
            f"{self._BASE}/droplets",
            headers={"Authorization": f"Bearer {credentials['token']}"},
        )
        with urllib.request.urlopen(req, timeout=15) as r:
            data = json.loads(r.read().decode() or "{}")
        return [
            {
                "name": d.get("name") or "Droplet",
                "provider": "DigitalOcean",
                "category": "software",
                "amount": 0,
                "currency": "USD",
                "cycle": "monthly",
                "next_due_date": None,
                "start_date": (d.get("created_at") or "")[:10] or None,
            }
            for d in data.get("droplets", [])
        ]
