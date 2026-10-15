"""Taux de change en ligne — deux sources, avec repli :

1. API Forex interne (api-forexplatform.sendbid.app) si les
   variables d'environnement RATES_CONVERT_URL / RATES_API_KEY /
   RATES_API_USER / RATES_API_PASSWORD sont configurées.
   Endpoint : POST /convert/ {from, to, amount} → market_rate.
2. Source publique de secours (open.er-api.com, sans clé).

Les taux sont mis en cache 12 h en mémoire pour éviter
d'appeler l'API externe à chaque requête mobile.
"""
import base64
import json
import os
import time
import urllib.request

_TTL = 12 * 3600  # 12 heures

_cache: dict[str, tuple[float, dict]] = {}

# Devises les plus courantes couvertes par l'app — le dictionnaire
# de taux retourné n'a pas besoin d'être exhaustif : le mobile ne
# convertit que les devises réellement utilisées.
_CURRENCIES = [
    "XAF", "XOF", "CDF", "GNF", "MGA", "MAD", "DZD", "TND",
    "NGN", "GHS", "KES", "ZAR", "RWF", "UGX", "TZS", "ETB",
    "EUR", "USD", "GBP", "CHF", "CAD", "JPY", "CNY", "INR",
    "AED", "SAR", "TRY", "BRL", "MXN", "AUD",
]


def _forex_configured() -> bool:
    return bool(
        os.getenv("RATES_CONVERT_URL")
        and os.getenv("RATES_API_KEY")
    )


def _forex_rate(base: str, target: str) -> float | None:
    """Interroge l'API Forex interne : 1 BASE = X TARGET
    (market_rate). Retourne None si indisponible."""
    url = os.getenv("RATES_CONVERT_URL", "").rstrip("/")
    user = os.getenv("RATES_API_USER", "")
    password = os.getenv("RATES_API_PASSWORD", "")
    api_key = os.getenv("RATES_API_KEY", "")
    body = json.dumps({
        "from_currency": base,
        "to_currency": target,
        "amount": 1,
    }).encode()
    req = urllib.request.Request(url, data=body, method="POST")
    req.add_header("Content-Type", "application/json")
    req.add_header("X-API-KEY", api_key)
    if user:
        creds = base64.b64encode(f"{user}:{password}".encode()).decode()
        req.add_header("Authorization", f"Basic {creds}")
    try:
        with urllib.request.urlopen(req, timeout=10) as r:
            data = json.loads(r.read().decode())
    except Exception:
        return None
    if not data.get("success"):
        return None
    try:
        return float(data["conversion"]["market_rate"])
    except (KeyError, TypeError, ValueError):
        return None


def _rates_forex(base: str) -> dict | None:
    """Construit le dictionnaire de taux depuis l'API Forex
    interne. None si le service ne répond pas correctement."""
    rates: dict[str, float] = {base: 1.0}
    hits = 0
    for target in _CURRENCIES:
        if target == base:
            continue
        rate = _forex_rate(base, target)
        if rate and rate > 0:
            rates[target] = rate
            hits += 1
    # Le service doit répondre sur au moins quelques paires,
    # sinon on considère qu'il est indisponible → repli.
    if hits < 3:
        return None
    return {"base": base, "date": "", "rates": rates, "source": "forex"}


def _rates_public(base: str) -> dict:
    """Repli : source publique gratuite (open.er-api.com)."""
    req = urllib.request.Request(
        f"https://open.er-api.com/v6/latest/{base}",
        headers={"Accept": "application/json"},
    )
    with urllib.request.urlopen(req, timeout=10) as r:
        data = json.loads(r.read().decode())
    if data.get("result") != "success":
        raise RuntimeError("Source de taux indisponible.")
    return {
        "base": base,
        "date": data.get("time_last_update_utc", ""),
        "rates": data["rates"],
        "source": "public",
    }


def rates_for(base: str) -> dict:
    """Retourne {base, date, rates:{XXX: taux}}.
    rate[EUR]=0.0016 → 1 BASE = 0.0016 EUR (base=XAF).
    Cache 12 h par devise de base."""
    base = (base or "USD").upper()
    cached = _cache.get(base)
    if cached and time.time() - cached[0] < _TTL:
        return cached[1]

    payload = _rates_forex(base) if _forex_configured() else None
    if payload is None:
        payload = _rates_public(base)
    _cache[base] = (time.time(), payload)
    return payload
