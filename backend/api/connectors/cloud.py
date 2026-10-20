"""Connecteurs cloud/hébergeurs supplémentaires — APIs Bearer/basic.

- Vultr   : https://www.vultr.com/api/ → API Key (Mon compte → API)
- UpCloud : https://api.upcloud.com/ → identifiants du compte (basic auth)
- Linode (Akamai) : https://techdocs.akamai.com/linode-api → PAT
- Cloudflare : https://developers.cloudflare.com/api/ → API token
"""
from __future__ import annotations

import base64
import json
import urllib.request


def _get_json(url: str, headers: dict):
    req = urllib.request.Request(url, headers=headers)
    with urllib.request.urlopen(req, timeout=15) as r:
        return json.loads(r.read().decode() or "{}")


class VultrConnector:
    slug = "vultr"
    label = "Vultr"
    description = (
        "Instances Vultr + frais en cours. my.vultr.com → Account → API Key."
    )
    auth_fields = [
        {"key": "token", "label": "Clé API", "secret": True},
    ]

    _BASE = "https://api.vultr.com/v2"

    def fetch(self, credentials: dict) -> list[dict]:
        h = {"Authorization": f"Bearer {credentials['token']}"}
        out = []
        pending = 0.0
        try:
            account = _get_json(f"{self._BASE}/account", h).get("account", {})
            pending = float(account.get("pending_charges") or 0)
        except Exception:
            pass
        servers = _get_json(f"{self._BASE}/instances", h)
        for s in servers.get("instances", []):
            out.append({
                "name": s.get("label") or s.get("hostname") or "Instance Vultr",
                "provider": "Vultr",
                "category": "software",
                "amount": 0,
                "currency": "USD",
                "cycle": "monthly",
                "next_due_date": None,
                "start_date": (s.get("date_created") or "")[:10] or None,
            })
        if pending > 0:
            out.insert(0, {
                "name": "Facture Vultr du mois",
                "provider": "Vultr",
                "category": "software",
                "amount": round(pending, 2),
                "currency": "USD",
                "cycle": "monthly",
                "next_due_date": None,
                "start_date": None,
            })
        return out


class UpCloudConnector:
    slug = "upcloud"
    label = "UpCloud"
    description = (
        "Serveurs UpCloud. hub.upcloud.com → People → API user "
        "(login + mot de passe du compte API)."
    )
    auth_fields = [
        {"key": "username", "label": "Utilisateur API", "secret": True},
        {"key": "password", "label": "Mot de passe API", "secret": True},
    ]

    _BASE = "https://api.upcloud.com/1.3"

    def fetch(self, credentials: dict) -> list[dict]:
        token = base64.b64encode(
            f"{credentials['username']}:{credentials['password']}".encode()
        ).decode()
        h = {"Authorization": f"Basic {token}"}
        data = _get_json(f"{self._BASE}/server", h)
        servers = (data.get("servers") or {}).get("server") or []
        return [
            {
                "name": s.get("title") or s.get("hostname") or "Serveur UpCloud",
                "provider": "UpCloud",
                "category": "software",
                "amount": 0,
                "currency": "EUR",
                "cycle": "monthly",
                "next_due_date": None,
                "start_date": (s.get("created") or "")[:10] or None,
            }
            for s in servers
            if s.get("state") != "maintenance"
        ]


class LinodeConnector:
    slug = "linode"
    label = "Linode (Akamai)"
    description = (
        "Instances Linode/Akamai. Cloud Manager → Profile → API Tokens → "
        "Personal Access Token."
    )
    auth_fields = [
        {"key": "token", "label": "Token API", "secret": True},
    ]

    _BASE = "https://api.linode.com/v4"

    def fetch(self, credentials: dict) -> list[dict]:
        h = {"Authorization": f"Bearer {credentials['token']}"}
        data = _get_json(f"{self._BASE}/linode/instances", h)
        return [
            {
                "name": d.get("label") or "Linode",
                "provider": "Linode",
                "category": "software",
                "amount": 0,
                "currency": "USD",
                "cycle": "monthly",
                "next_due_date": None,
                "start_date": (d.get("created") or "")[:10] or None,
            }
            for d in data.get("data", [])
        ]


class CloudflareConnector:
    slug = "cloudflare"
    label = "Cloudflare"
    description = (
        "Zones et plans Cloudflare. Dashboard → My Profile → API Tokens "
        "(droits Zone.Read + Account subscriptions en lecture)."
    )
    auth_fields = [
        {"key": "token", "label": "Token API", "secret": True},
    ]

    _BASE = "https://api.cloudflare.com/client/v4"

    def fetch(self, credentials: dict) -> list[dict]:
        h = {"Authorization": f"Bearer {credentials['token']}"}
        out = []
        accounts = _get_json(f"{self._BASE}/accounts?per_page=20", h)
        for acc in accounts.get("result") or []:
            acc_id = acc.get("id")
            if not acc_id:
                continue
            try:
                subs = _get_json(
                    f"{self._BASE}/accounts/{acc_id}/subscriptions", h
                )
            except Exception:
                continue
            for s in subs.get("result") or []:
                price = s.get("price") or 0
                zones = (s.get("zone") or {}).get("name")
                out.append({
                    "name": zones or s.get("id") or "Abonnement Cloudflare",
                    "provider": "Cloudflare",
                    "category": "software",
                    "amount": float(price),
                    "currency": (s.get("currency") or "USD").upper(),
                    "cycle": {"year": "yearly"}.get(
                        s.get("frequency"), "monthly"
                    ),
                    "next_due_date": (s.get("current_period_end")
                                      or "")[:10] or None,
                    "start_date": (s.get("current_period_start")
                                   or "")[:10] or None,
                })
        # Domaines enregistrés chez Cloudflare Registrar : date d'expiration.
        try:
            accounts_ids = [
                a["id"] for a in accounts.get("result") or [] if a.get("id")
            ]
            for acc_id in accounts_ids:
                domains = _get_json(
                    f"{self._BASE}/accounts/{acc_id}/registrar/domains", h
                )
                for d in domains.get("result") or []:
                    out.append({
                        "name": f"Domaine {d.get('name')}",
                        "provider": "Cloudflare Registrar",
                        "category": "software",
                        "amount": 0,
                        "currency": "USD",
                        "cycle": "yearly",
                        "next_due_date": (d.get("expires_at")
                                          or "")[:10] or None,
                        "start_date": (d.get("created_at")
                                       or "")[:10] or None,
                    })
        except Exception:
            pass
        return out
