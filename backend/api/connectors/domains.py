"""Connecteurs registrars de domaines — les dates d'expiration
sont les vraies échéances de renouvellement.

- Gandi     : https://api.gandi.net — account.gandi.net → Security → API key
- GoDaddy   : https://developer.godaddy.com/keys — API Key + Secret
- Namecheap : https://www.namecheap.com → Profile → Tools → API access
              (nécessite d'autoriser l'IP serveur dans Namecheap)
"""
from __future__ import annotations

import json
import urllib.parse
import urllib.request
import xml.etree.ElementTree as ET


class GandiConnector:
    slug = "gandi"
    label = "Gandi"
    description = (
        "Domaines et boîtes mail Gandi — échéance = expiration du domaine. "
        "account.gandi.net → Sécurité → Clé API."
    )
    auth_fields = [
        {"key": "api_key", "label": "Clé API", "secret": True},
    ]

    _BASE = "https://api.gandi.net/v5"

    def fetch(self, credentials: dict) -> list[dict]:
        req = urllib.request.Request(
            f"{self._BASE}/domain/domains?per_page=100",
            headers={
                "Authorization": f"Apikey {credentials['api_key']}"
            },
        )
        with urllib.request.urlopen(req, timeout=15) as r:
            domains = json.loads(r.read().decode() or "[]")
        out = []
        for d in domains:
            dates = d.get("dates") or {}
            out.append({
                "name": f"Domaine {d.get('fqdn_unicode') or d.get('fqdn')}",
                "provider": "Gandi",
                "category": "software",
                "amount": 0,
                "currency": "EUR",
                "cycle": "yearly",
                "next_due_date": (dates.get("registry_ends_at")
                                  or "")[:10] or None,
                "start_date": (dates.get("registry_created_at")
                               or "")[:10] or None,
            })
        return out


class GoDaddyConnector:
    slug = "godaddy"
    label = "GoDaddy"
    description = (
        "Domaines GoDaddy — échéance = date d'expiration. "
        "developer.godaddy.com/keys → API Key + Secret."
    )
    auth_fields = [
        {"key": "api_key", "label": "API Key", "secret": True},
        {"key": "api_secret", "label": "API Secret", "secret": True},
    ]

    _BASE = "https://api.godaddy.com/v1"

    def fetch(self, credentials: dict) -> list[dict]:
        req = urllib.request.Request(
            f"{self._BASE}/domains?statuses=ACTIVE&limit=100",
            headers={
                "Authorization": "sso-key "
                f"{credentials['api_key']}:{credentials['api_secret']}",
            },
        )
        with urllib.request.urlopen(req, timeout=15) as r:
            domains = json.loads(r.read().decode() or "[]")
        out = []
        for d in domains:
            out.append({
                "name": f"Domaine {d.get('domain')}",
                "provider": "GoDaddy",
                "category": "software",
                "amount": 0,
                "currency": "USD",
                "cycle": "yearly",
                "next_due_date": (d.get("expires") or "")[:10] or None,
                "start_date": (d.get("createdAt") or "")[:10] or None,
            })
        return out


class NamecheapConnector:
    slug = "namecheap"
    label = "Namecheap"
    description = (
        "Domaines Namecheap — échéance = expiration. Nécessite d'activer "
        "l'accès API et d'autoriser l'IP du serveur dans Namecheap → "
        "Profile → Tools."
    )
    auth_fields = [
        {"key": "username", "label": "Utilisateur Namecheap",
         "secret": False},
        {"key": "api_key", "label": "Clé API", "secret": True},
        {"key": "client_ip", "label": "IP autorisée (votre serveur)",
         "secret": False},
    ]

    _BASE = "https://api.namecheap.com/xml.response"

    def fetch(self, credentials: dict) -> list[dict]:
        params = {
            "ApiUser": credentials["username"],
            "UserName": credentials["username"],
            "ApiKey": credentials["api_key"],
            "ClientIp": credentials.get("client_ip") or "",
            "Command": "namecheap.domains.getList",
            "PageSize": "100",
        }
        url = f"{self._BASE}?{urllib.parse.urlencode(params)}"
        with urllib.request.urlopen(url, timeout=15) as r:
            root = ET.fromstring(r.read().decode())
        ns = ""
        if root.tag.startswith("{"):
            ns = root.tag.split("}")[0] + "}"
        out = []
        for dom in root.iter(f"{ns}Domain"):
            out.append({
                "name": f"Domaine {dom.get('Name')}",
                "provider": "Namecheap",
                "category": "software",
                "amount": 0,
                "currency": "USD",
                "cycle": "yearly",
                "next_due_date": (dom.get("Expires") or "")[:10] or None,
                "start_date": (dom.get("Created") or "")[:10] or None,
            })
        return out
