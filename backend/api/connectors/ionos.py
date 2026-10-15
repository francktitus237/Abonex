"""Connecteur IONOS — Cloud API (token Bearer).
https://api.ionos.com/docs/cloud/v6/
"""
from __future__ import annotations

import json
import urllib.request


class IonosConnector:
    slug = "ionos"
    label = "IONOS"
    description = (
        "Serveurs cloud IONOS. Renseignez votre token API "
        "(Contract Manager → API) pour importer vos serveurs."
    )
    auth_fields = [
        {"key": "token", "label": "Token API", "secret": True},
    ]

    _BASE = "https://api.ionos.com/cloudapi/v6"

    def _get(self, token: str, path: str):
        req = urllib.request.Request(
            f"{self._BASE}{path}",
            headers={"Authorization": f"Bearer {token}"},
        )
        with urllib.request.urlopen(req, timeout=15) as r:
            return json.loads(r.read().decode() or "{}")

    def fetch(self, credentials: dict) -> list[dict]:
        token = credentials["token"]
        datacenters = self._get(token, "/datacenters?depth=1")
        out = []
        for dc in datacenters.get("items", []):
            dc_id = dc["id"]
            try:
                servers = self._get(
                    token, f"/datacenters/{dc_id}/servers?depth=1"
                )
            except Exception:
                continue
            for srv in servers.get("items", []):
                props = srv.get("properties", {})
                out.append({
                    "name": props.get("name") or "Serveur IONOS",
                    "provider": "IONOS",
                    "category": "software",
                    "amount": 0,
                    "currency": "EUR",
                    "cycle": "monthly",
                    "next_due_date": None,
                    "start_date": (srv.get("metadata", {})
                                   .get("createdDate") or "")[:10] or None,
                })
        return out
