"""Registre des connecteurs disponibles.

Un connecteur est un objet avec :
- slug, label, description
- auth_fields : liste de {key, label, secret} affichés dans l'app
- fetch(credentials: dict) -> list[dict] d'abonnements normalisés

Sécurité : les credentials passent chiffrés côté serveur et ne sont
jamais renvoyés au client.
"""
from __future__ import annotations

from .billing import (
    GoCardlessConnector,
    MollieConnector,
    PaddleConnector,
)
from .cloud import (
    CloudflareConnector,
    LinodeConnector,
    UpCloudConnector,
    VultrConnector,
)
from .domains import GandiConnector, GoDaddyConnector, NamecheapConnector
from .hetzner import DigitalOceanConnector, HetznerConnector
from .ionos import IonosConnector
from .ovh import OvhConnector
from .powens import PowensConnector
from .stripe import StripeConnector

CONNECTORS = {
    c.slug: c
    for c in (
        OvhConnector(),
        IonosConnector(),
        HetznerConnector(),
        DigitalOceanConnector(),
        VultrConnector(),
        UpCloudConnector(),
        LinodeConnector(),
        CloudflareConnector(),
        GandiConnector(),
        GoDaddyConnector(),
        NamecheapConnector(),
        StripeConnector(),
        MollieConnector(),
        PaddleConnector(),
        GoCardlessConnector(),
        PowensConnector(),
    )
}

# Métadonnées de présentation — groupe d'affichage dans l'app et
# pays où le connecteur est pertinent ("*" = tous).
CONNECTOR_META = {
    "ovh":          {"group": "cloud",    "countries": ["FR", "CA", "*"]},
    "ionos":        {"group": "cloud",    "countries": ["*"]},
    "hetzner":      {"group": "cloud",    "countries": ["*"]},
    "digitalocean": {"group": "cloud",    "countries": ["*"]},
    "vultr":        {"group": "cloud",    "countries": ["*"]},
    "upcloud":      {"group": "cloud",    "countries": ["*"]},
    "linode":       {"group": "cloud",    "countries": ["*"]},
    "cloudflare":   {"group": "cloud",    "countries": ["*"]},
    "gandi":        {"group": "domains",  "countries": ["FR", "BE", "LU", "*"]},
    "godaddy":      {"group": "domains",  "countries": ["*"]},
    "namecheap":    {"group": "domains",  "countries": ["*"]},
    "stripe":       {"group": "payments", "countries": ["*"]},
    "mollie":       {"group": "payments", "countries": ["*"]},
    "paddle":       {"group": "payments", "countries": ["*"]},
    "gocardless":   {"group": "payments", "countries": ["*"]},
    "powens":       {"group": "bank",     "countries": ["*"]},
}

# Ordre/libellés des groupes dans l'app.
CONNECTOR_GROUPS = {
    "bank":     "Compte bancaire",
    "cloud":    "Cloud, serveurs & SaaS",
    "domains":  "Domaines & registrars",
    "payments": "Paiements récurrents",
}


def connector_meta(slug: str) -> dict:
    return CONNECTOR_META.get(slug, {"group": "other", "countries": ["*"]})


def get_connector(slug: str):
    return CONNECTORS.get(slug)
