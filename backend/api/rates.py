"""Taux de change en ligne — source publique gratuite
(open.er-api.com, mise à jour quotidienne, sans clé).

Les taux sont mis en cache 12 h en mémoire pour éviter
d'appeler l'API externe à chaque requête mobile.
"""
import json
import time
import urllib.request

_SOURCE = "https://open.er-api.com/v6/latest/{base}"
_TTL = 12 * 3600  # 12 heures

_cache: dict[str, tuple[float, dict]] = {}


def rates_for(base: str) -> dict:
    """Retourne {base, date, rates:{XXX: taux}}.
    rate[EUR]=0.0016 → 1 XAF = 0.0016 EUR (base=XAF)."""
    base = (base or "USD").upper()
    cached = _cache.get(base)
    if cached and time.time() - cached[0] < _TTL:
        return cached[1]
    req = urllib.request.Request(
        _SOURCE.format(base=base),
        headers={"Accept": "application/json"},
    )
    with urllib.request.urlopen(req, timeout=10) as r:
        data = json.loads(r.read().decode())
    if data.get("result") != "success":
        raise RuntimeError("Source de taux indisponible.")
    payload = {
        "base": base,
        "date": data.get("time_last_update_utc", ""),
        "rates": data["rates"],
    }
    _cache[base] = (time.time(), payload)
    return payload
