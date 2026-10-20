"""Connecteurs de fournisseurs : import automatique d'abonnements
depuis les APIs externes (OVH, IONOS…).

Chaque connecteur déclare :
- `slug`        : identifiant stable utilisé par l'API REST
- `label`       : nom lisible
- `auth_fields` : champs demandés à l'utilisateur (clés API…)
- `fetch(credentials)` → liste d'objets "abonnement importable"
  normalisés : {name, provider, category, amount, currency,
  next_due_date, cycle, start_date}
"""
from .registry import (
    CONNECTOR_GROUPS,
    CONNECTORS,
    connector_meta,
    get_connector,
)

__all__ = [
    "CONNECTOR_GROUPS",
    "CONNECTORS",
    "connector_meta",
    "get_connector",
]
