"""Catalogue de fournisseurs connus par pays.

Sert à deux choses :
- proposer des suggestions de fournisseurs lors de l'ajout d'un
  abonnement selon le pays du workspace ;
- pré-remplir catégorie/cycle pour accélérer la saisie.

Liste non exhaustive, extensible — couvre l'Afrique francophone,
l'Union européenne, l'Asie et les Amériques.
"""

CATALOG = [
    # --- International (tous pays) ---
    {"name": "OVHcloud", "category": "software", "countries": ["*"]},
    {"name": "IONOS", "category": "software", "countries": ["*"]},
    {"name": "Amazon Web Services", "category": "software",
     "countries": ["*"]},
    {"name": "Google Cloud", "category": "software", "countries": ["*"]},
    {"name": "Microsoft Azure", "category": "software", "countries": ["*"]},
    {"name": "Google Workspace", "category": "software", "countries": ["*"]},
    {"name": "Microsoft 365", "category": "software", "countries": ["*"]},
    {"name": "Netflix", "category": "software", "countries": ["*"]},
    {"name": "Spotify", "category": "software", "countries": ["*"]},
    {"name": "Canal+", "category": "software", "countries": ["*"]},

    # --- Afrique francophone / CEMAC / UEMOA ---
    {"name": "ENEO", "category": "energy", "countries": ["CM"]},
    {"name": "Camwater / CDE", "category": "water", "countries": ["CM"]},
    {"name": "Orange Cameroun", "category": "telecom", "countries": ["CM"]},
    {"name": "MTN Cameroun", "category": "telecom", "countries": ["CM"]},
    {"name": "Camtel", "category": "telecom", "countries": ["CM"]},
    {"name": "Nexttel", "category": "telecom", "countries": ["CM"]},
    {"name": "Yoomee", "category": "telecom", "countries": ["CM"]},
    {"name": "CIE", "category": "energy", "countries": ["CI"]},
    {"name": "SODECI", "category": "water", "countries": ["CI"]},
    {"name": "SENELEC", "category": "energy", "countries": ["SN"]},
    {"name": "SDE / SEN'EAU", "category": "water", "countries": ["SN"]},
    {"name": "SEEG", "category": "energy", "countries": ["GA"]},
    {"name": "CEB", "category": "energy", "countries": ["TG", "BJ"]},
    {"name": "SONEDE", "category": "water", "countries": ["TN"]},
    {"name": "STEG", "category": "energy", "countries": ["TN"]},
    {"name": "JIRAMA", "category": "energy", "countries": ["MG"]},
    {"name": "ONEA", "category": "water", "countries": ["BF"]},
    {"name": "SONABEL", "category": "energy", "countries": ["BF"]},
    {"name": "SENELEC / Orange Sénégal", "category": "telecom",
     "countries": ["SN"]},
    {"name": "Moov Africa", "category": "telecom",
     "countries": ["BJ", "CI", "TG", "BF", "NE", "GA", "CD"]},
    {"name": "Airtel Africa", "category": "telecom",
     "countries": ["GA", "CD", "CG", "MG", "TD", "NE"]},
    {"name": "LYDEC", "category": "energy", "countries": ["MA"]},
    {"name": "ONEE", "category": "energy", "countries": ["MA"]},
    {"name": "Inwi", "category": "telecom", "countries": ["MA"]},
    {"name": "Maroc Telecom", "category": "telecom", "countries": ["MA"]},
    {"name": "SONELGAZ", "category": "energy", "countries": ["DZ"]},
    {"name": "ADE", "category": "water", "countries": ["DZ"]},
    {"name": "Mobilis / Djezzy / Ooredoo", "category": "telecom",
     "countries": ["DZ"]},

    # --- Union européenne ---
    {"name": "EDF", "category": "energy", "countries": ["FR"]},
    {"name": "Engie", "category": "energy", "countries": ["FR", "BE"]},
    {"name": "TotalEnergies", "category": "energy", "countries": ["FR", "BE"]},
    {"name": "Orange France", "category": "telecom", "countries": ["FR"]},
    {"name": "SFR", "category": "telecom", "countries": ["FR"]},
    {"name": "Bouygues Telecom", "category": "telecom", "countries": ["FR"]},
    {"name": "Free", "category": "telecom", "countries": ["FR"]},
    {"name": "Veolia / Suez (eau)", "category": "water", "countries": ["FR"]},
    {"name": "URSSAF", "category": "other", "countries": ["FR"]},
    {"name": "Assurance habitation/pro", "category": "insurance",
     "countries": ["FR", "BE", "DE", "ES", "IT"]},
    {"name": "Enel", "category": "energy", "countries": ["IT", "ES"]},
    {"name": "Iberdrola", "category": "energy", "countries": ["ES"]},
    {"name": "Movistar", "category": "telecom", "countries": ["ES"]},
    {"name": "Vodafone", "category": "telecom",
     "countries": ["DE", "ES", "IT", "GB", "PT"]},
    {"name": "Telefónica / O2", "category": "telecom",
     "countries": ["DE", "ES", "GB"]},
    {"name": "Deutsche Telekom", "category": "telecom", "countries": ["DE"]},
    {"name": "Proximus", "category": "telecom", "countries": ["BE"]},
    {"name": "KPN", "category": "telecom", "countries": ["NL"]},

    # --- Amériques ---
    {"name": "Comcast / Xfinity", "category": "telecom", "countries": ["US"]},
    {"name": "Verizon", "category": "telecom", "countries": ["US"]},
    {"name": "AT&T", "category": "telecom", "countries": ["US"]},
    {"name": "Con Edison", "category": "energy", "countries": ["US"]},
    {"name": "Hydro-Québec", "category": "energy", "countries": ["CA"]},
    {"name": "Bell / Rogers / Telus", "category": "telecom",
     "countries": ["CA"]},
    {"name": "CFE", "category": "energy", "countries": ["MX"]},
    {"name": "Telcel / Telmex", "category": "telecom", "countries": ["MX"]},
    {"name": "Sabesp / eau municipale", "category": "water",
     "countries": ["BR"]},
    {"name": "Claro / Vivo", "category": "telecom", "countries": ["BR"]},

    # --- Asie ---
    {"name": "Jio / Airtel India", "category": "telecom", "countries": ["IN"]},
    {"name": "China Mobile", "category": "telecom", "countries": ["CN"]},
    {"name": "PLDT / Globe", "category": "telecom", "countries": ["PH"]},
    {"name": "Singtel", "category": "telecom", "countries": ["SG"]},
    {"name": "Etisalat / du", "category": "telecom", "countries": ["AE"]},
    {"name": "DEWA", "category": "energy", "countries": ["AE"]},
]


def providers_for(country_code: str) -> list[dict]:
    """Fournisseurs internationaux + ceux du pays demandé."""
    code = (country_code or "").upper()
    return [
        {"name": p["name"], "category": p["category"]}
        for p in CATALOG
        if "*" in p["countries"] or code in p["countries"]
    ]
