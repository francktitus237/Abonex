"""Connecteur Powens (ex-Budget Insight) — agrégation bancaire PSD2.

Flux OAuth conforme : l'utilisateur se connecte à SA BANQUE dans le
webview Powens — Abonex ne voit jamais les identifiants bancaires.
Powens renvoie un `code` échangé contre un access_token, puis on
lit les transactions pour détecter les prélèvements récurrents
(EDF, eau, loyer, abonnements…) avec vraies dates et montants.

Configuration serveur (variables d'environnement) :
- POWENS_CLIENT_ID     : client_id de l'application Powens
- POWENS_CLIENT_SECRET : client_secret
- POWENS_DOMAIN        : domaine API Powens (sandbox.biapi.pro en test,
                         <client>.biapi.pro en production — voir console)
- POWENS_BASE          : URL d'API complète (prioritaire sur POWENS_DOMAIN)
- POWENS_REDIRECT_URI  : URI de redirection enregistrée chez Powens
                         (défaut abonex://powens/callback)
"""
from __future__ import annotations

import json
import os
import re
import statistics
import urllib.parse
import urllib.request
from datetime import date, timedelta


def _config() -> dict:
    domain = os.getenv("POWENS_DOMAIN", "demo.biapi.pro")
    return {
        "client_id": os.getenv("POWENS_CLIENT_ID", ""),
        "client_secret": os.getenv("POWENS_CLIENT_SECRET", ""),
        "base": os.getenv("POWENS_BASE", f"https://{domain}/2.0"),
        "redirect_uri": os.getenv(
            "POWENS_REDIRECT_URI", "abonex://powens/callback"
        ),
    }


def is_configured() -> bool:
    c = _config()
    return bool(c["client_id"] and c["client_secret"])


def build_auth_url(country: str = "fr") -> str:
    """URL du webview Powens à ouvrir dans l'app."""
    c = _config()
    params = {
        "client_id": c["client_id"],
        "redirect_uri": c["redirect_uri"],
        "country": country.lower() or "fr",
        "type": "single",
    }
    return "https://webview.powens.com/fr/connect?" + urllib.parse.urlencode(
        params
    )


def exchange_code(code: str) -> dict:
    """Échange le code OAuth contre un access_token + id utilisateur."""
    c = _config()
    params = urllib.parse.urlencode({
        "client_id": c["client_id"],
        "client_secret": c["client_secret"],
        "code": code,
    }).encode()
    req = urllib.request.Request(f"{c['base']}/token", data=params)
    with urllib.request.urlopen(req, timeout=15) as r:
        return json.loads(r.read().decode() or "{}")


def _get(token: str, path: str):
    req = urllib.request.Request(
        f"{_config()['base']}{path}",
        headers={"Authorization": f"Bearer {token}"},
    )
    with urllib.request.urlopen(req, timeout=20) as r:
        return json.loads(r.read().decode() or "{}")


# ------------------------------------------------------------------
# Détection de récurrence : regroupe les transactions par libellé
# normalisé + montant quasi identique, puis déduit le cycle.
# ------------------------------------------------------------------

_CLEAN = re.compile(r"[\d\*#\-_/\\]+")


def _clean_label(wording: str) -> str:
    label = _CLEAN.sub(" ", wording or "")
    label = re.sub(r"\s+", " ", label).strip()
    return label[:60] or "Prélèvement"


_CATEGORIES = [
    ("energy", ["edf", "engie", "enedis", "totalenergie", "ekwateur",
                "eneo", "sonelgaz", "steg", "jirama", "cie"]),
    ("water", ["camwater", "cde", "sodeci", "sde ", "veolia", "suez",
               "lydec", "sonees", "onea"]),
    ("telecom", ["orange", "sfr", "free", "bouygues", "mtn", "moov",
                 "airtel", "vodafone", "proximus", "kpn", "inwi",
                 "telecel", "yoomee", "nexttel", "camtel"]),
    ("software", ["netflix", "spotify", "canal", "disney", "amazon",
                  "prime", "apple", "google", "microsoft", "adobe",
                  "deezer", "youtube", "chatgpt", "openai", "ovh",
                  "ionos", "hetzner", "cloud"]),
    ("rent", ["loyer", "bail", "regie", "foncia", "nexity", "orpi",
              "century", "logic-immo"]),
    ("insurance", ["assurance", "maif", "macif", "matmut", "axa",
                   "groupama", "allianz", "generali", "mutuelle"]),
    ("transport", ["sncf", "ratp", "uber", "bolt", "navigo", "transdev"]),
    ("payroll", ["salaire", "paie", "bulletin"]),
]


def _guess_category(label: str) -> str:
    low = label.lower()
    for cat, keywords in _CATEGORIES:
        if any(k in low for k in keywords):
            return cat
    return "other"


def _cycle_for(median_days: float) -> str | None:
    if 20 <= median_days <= 40:
        return "monthly"
    if 80 <= median_days <= 100:
        return "quarterly"
    if 340 <= median_days <= 380:
        return "yearly"
    return None


def detect_recurring(transactions: list[dict]) -> list[dict]:
    """Transforme les prélèvements récurrents en abonnements normalisés."""
    groups: dict[str, list[dict]] = {}
    for t in transactions:
        value = float(t.get("value") or 0)
        if value >= 0:
            continue  # on ne suit que les DÉBITS (paiements)
        label = _clean_label(t.get("clean_wording") or t.get("wording"))
        groups.setdefault(label, []).append(t)

    out = []
    for label, txs in groups.items():
        txs = sorted(txs, key=lambda t: t.get("date") or "")
        if len(txs) < 2:
            continue
        amounts = [abs(float(t.get("value") or 0)) for t in txs]
        median_amount = statistics.median(amounts)
        if median_amount <= 0:
            continue
        # Montants stables : écart max 15 % autour de la médiane.
        if max(amounts) > median_amount * 1.15:
            continue
        dates = [
            date.fromisoformat(t["date"]) for t in txs if t.get("date")
        ]
        if len(dates) < 2:
            continue
        gaps = [
            (b - a).days for a, b in zip(dates, dates[1:]) if (b - a).days > 0
        ]
        if not gaps:
            continue
        cycle = _cycle_for(statistics.median(gaps))
        if cycle is None:
            continue
        step = {"monthly": 30, "quarterly": 91, "yearly": 365}[cycle]
        next_due = dates[-1] + timedelta(days=step)
        out.append({
            "name": label,
            "provider": label,
            "category": _guess_category(label),
            "amount": round(median_amount, 2),
            "currency": "EUR",
            "cycle": cycle,
            "next_due_date": next_due.isoformat(),
            "start_date": dates[0].isoformat(),
        })
    out.sort(key=lambda x: x["next_due_date"])
    return out


class PowensConnector:
    """Connecteur banque — OAuth webview (pas de formulaire de login)."""

    slug = "powens"
    label = "Ma banque"
    description = (
        "Synchronisation bancaire sécurisée via Powens : détection "
        "automatique de tous vos prélèvements récurrents (énergie, "
        "eau, télécom, loyer, streaming…)."
    )
    # Pas de champs : la connexion passe par le webview OAuth Powens.
    auth_fields = []
    oauth = True

    def fetch(self, credentials: dict) -> list[dict]:
        """Re-synchronisation : credentials = {access_token}."""
        token = credentials["access_token"]
        min_date = (date.today() - timedelta(days=240)).isoformat()
        data = _get(
            token,
            f"/users/me/transactions?limit=1000&min_date={min_date}",
        )
        return detect_recurring(data.get("transactions") or [])
