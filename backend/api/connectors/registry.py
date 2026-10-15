"""Registre des connecteurs disponibles.

Un connecteur est un objet avec :
- slug, label, description
- auth_fields : liste de {key, label, secret} affichés dans l'app
- fetch(credentials: dict) -> list[dict] d'abonnements normalisés

Sécurité : les credentials passent chiffrés côté serveur et ne sont
jamais renvoyés au client.
"""
from __future__ import annotations

from .hetzner import DigitalOceanConnector, HetznerConnector
from .ionos import IonosConnector
from .ovh import OvhConnector
from .stripe import StripeConnector

CONNECTORS = {
    c.slug: c
    for c in (
        OvhConnector(),
        IonosConnector(),
        HetznerConnector(),
        DigitalOceanConnector(),
        StripeConnector(),
    )
}


def get_connector(slug: str):
    return CONNECTORS.get(slug)
