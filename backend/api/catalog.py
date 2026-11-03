"""Catalogue de fournisseurs connus par pays.

Sert à deux choses :
- proposer des suggestions de fournisseurs lors de l'ajout d'un
  abonnement selon le pays du workspace ;
- pré-remplir catégorie/cycle pour accélérer la saisie.

Liste non exhaustive, extensible — couvre l'Afrique francophone,
l'Union européenne, l'Asie et les Amériques.

`origin` : pays du fournisseur (ISO alpha-2) — siège social pour les
groupes internationaux, pays d'exploitation pour les filiales locales
(ex. Orange Cameroun → CM). Affiché sous forme de drapeau dans l'app.
"""

CATALOG = [
    # --- International (tous pays) ---
    {"name": "OVHcloud", "origin": "FR", "category": "software", "countries": ["*"]},
    {"name": "IONOS", "origin": "DE", "category": "software", "countries": ["*"]},
    {"name": "Amazon Web Services", "origin": "US", "category": "software",
     "countries": ["*"]},
    {"name": "Google Cloud", "origin": "US", "category": "software", "countries": ["*"]},
    {"name": "Microsoft Azure", "origin": "US", "category": "software", "countries": ["*"]},
    {"name": "Google Workspace", "origin": "US", "category": "software", "countries": ["*"]},
    {"name": "Microsoft 365", "origin": "US", "group": "productivity", "category": "software", "countries": ["*"],
     "plans": [
         {"label": "Basic", "amount": 7.20, "currency": "EUR",
          "cycle": "monthly"},
         {"label": "Standard", "amount": 14.40, "currency": "EUR",
          "cycle": "monthly"},
         {"label": "Perso", "amount": 10.00, "currency": "EUR",
          "cycle": "monthly"},
         {"label": "Famille (an)", "amount": 100.00, "currency": "EUR",
          "cycle": "yearly"},
     ]},
    {"name": "Netflix", "origin": "US", "group": "streaming", "category": "software", "countries": ["*"],
     "plans": [
         {"label": "Standard", "amount": 13.49, "currency": "EUR",
          "cycle": "monthly"},
         {"label": "Premium", "amount": 19.99, "currency": "EUR",
          "cycle": "monthly"},
         {"label": "Essentiel", "amount": 9.99, "currency": "EUR",
          "cycle": "monthly"},
     ]},
    {"name": "Spotify", "origin": "SE", "group": "music", "category": "software", "countries": ["*"],
     "plans": [
         {"label": "Premium", "amount": 11.99, "currency": "EUR",
          "cycle": "monthly"},
         {"label": "Duo", "amount": 15.99, "currency": "EUR",
          "cycle": "monthly"},
         {"label": "Famille", "amount": 18.99, "currency": "EUR",
          "cycle": "monthly"},
     ]},
    {"name": "Canal+", "origin": "FR", "group": "streaming", "category": "software", "countries": ["*"],
     "plans": [
         {"label": "Essentiel", "amount": 9.99, "currency": "EUR",
          "cycle": "monthly"},
         {"label": "Canal+", "amount": 22.99, "currency": "EUR",
          "cycle": "monthly"},
     ]},
    {"name": "Disney+", "origin": "US", "group": "streaming", "category": "software", "countries": ["*"],
     "plans": [
         {"label": "Standard", "amount": 8.99, "currency": "EUR",
          "cycle": "monthly"},
         {"label": "Premium", "amount": 11.99, "currency": "EUR",
          "cycle": "monthly"},
     ]},
    {"name": "Prime Video", "origin": "US", "group": "streaming", "category": "software", "countries": ["*"],
     "plans": [
         {"label": "Amazon Prime", "amount": 6.99, "currency": "EUR",
          "cycle": "monthly"},
         {"label": "Amazon Prime (an)", "amount": 69.90, "currency": "EUR",
          "cycle": "yearly"},
     ]},
    {"name": "YouTube Premium", "origin": "US", "group": "streaming", "category": "software", "countries": ["*"],
     "plans": [
         {"label": "Individuel", "amount": 12.99, "currency": "EUR",
          "cycle": "monthly"},
         {"label": "Famille", "amount": 23.99, "currency": "EUR",
          "cycle": "monthly"},
     ]},
    {"name": "Apple Music", "origin": "US", "group": "music", "category": "software", "countries": ["*"],
     "plans": [
         {"label": "Individuel", "amount": 11.99, "currency": "EUR",
          "cycle": "monthly"},
         {"label": "Famille", "amount": 17.99, "currency": "EUR",
          "cycle": "monthly"},
     ]},
    {"name": "Deezer", "origin": "FR", "group": "music", "category": "software", "countries": ["*"],
     "plans": [
         {"label": "Premium", "amount": 11.99, "currency": "EUR",
          "cycle": "monthly"},
         {"label": "Famille", "amount": 19.99, "currency": "EUR",
          "cycle": "monthly"},
     ]},
    {"name": "Apple iCloud+", "origin": "US", "group": "storage", "category": "software", "countries": ["*"],
     "plans": [
         {"label": "50 Go", "amount": 0.99, "currency": "EUR",
          "cycle": "monthly"},
         {"label": "200 Go", "amount": 2.99, "currency": "EUR",
          "cycle": "monthly"},
         {"label": "2 To", "amount": 9.99, "currency": "EUR",
          "cycle": "monthly"},
     ]},
    {"name": "Google One", "origin": "US", "group": "storage", "category": "software", "countries": ["*"],
     "plans": [
         {"label": "100 Go", "amount": 1.99, "currency": "EUR",
          "cycle": "monthly"},
         {"label": "200 Go", "amount": 2.99, "currency": "EUR",
          "cycle": "monthly"},
         {"label": "2 To", "amount": 9.99, "currency": "EUR",
          "cycle": "monthly"},
     ]},
    {"name": "ChatGPT Plus", "origin": "US", "group": "productivity", "category": "software", "countries": ["*"],
     "plans": [
         {"label": "Plus", "amount": 23.00, "currency": "EUR",
          "cycle": "monthly"},
         {"label": "Pro", "amount": 229.00, "currency": "EUR",
          "cycle": "monthly"},
     ]},
    {"name": "Xbox Game Pass", "origin": "US", "group": "gaming", "category": "software", "countries": ["*"],
     "plans": [
         {"label": "Ultimate", "amount": 17.99, "currency": "EUR",
          "cycle": "monthly"},
         {"label": "Standard", "amount": 12.99, "currency": "EUR",
          "cycle": "monthly"},
     ]},
    {"name": "PlayStation Plus", "origin": "JP", "group": "gaming", "category": "software",
     "countries": ["*"],
     "plans": [
         {"label": "Essentiel", "amount": 8.99, "currency": "EUR",
          "cycle": "monthly"},
         {"label": "Extra", "amount": 13.99, "currency": "EUR",
          "cycle": "monthly"},
         {"label": "Premium", "amount": 16.99, "currency": "EUR",
          "cycle": "monthly"},
     ]},
    {"name": "Nintendo Switch Online", "origin": "JP", "group": "gaming", "category": "software",
     "countries": ["*"],
     "plans": [
         {"label": "Individuel (an)", "amount": 19.99, "currency": "EUR",
          "cycle": "yearly"},
         {"label": "Famille (an)", "amount": 34.99, "currency": "EUR",
          "cycle": "yearly"},
     ]},
    {"name": "Adobe Creative Cloud", "origin": "US", "group": "productivity", "category": "software",
     "countries": ["*"],
     "plans": [
         {"label": "1 application", "amount": 23.99, "currency": "EUR",
          "cycle": "monthly"},
         {"label": "Toutes les apps", "amount": 59.99, "currency": "EUR",
          "cycle": "monthly"},
     ]},
    {"name": "Notion", "origin": "US", "group": "productivity", "category": "software", "countries": ["*"],
     "plans": [
         {"label": "Plus", "amount": 12.00, "currency": "USD",
          "cycle": "monthly"},
     ]},
    {"name": "LinkedIn Premium", "origin": "US", "group": "productivity", "category": "software",
     "countries": ["*"],
     "plans": [
         {"label": "Career", "amount": 35.00, "currency": "EUR",
          "cycle": "monthly"},
     ]},
    {"name": "Duolingo Super", "origin": "US", "group": "productivity", "category": "software", "countries": ["*"],
     "plans": [
         {"label": "Super", "amount": 7.49, "currency": "EUR",
          "cycle": "monthly"},
         {"label": "Super (an)", "amount": 89.99, "currency": "EUR",
          "cycle": "yearly"},
     ]},
    {"name": "NordVPN", "origin": "PA", "group": "security", "category": "software", "countries": ["*"],
     "plans": [
         {"label": "Standard", "amount": 12.99, "currency": "EUR",
          "cycle": "monthly"},
         {"label": "Standard (an)", "amount": 59.88, "currency": "EUR",
          "cycle": "yearly"},
     ]},
    {"name": "GitHub Copilot", "origin": "US", "group": "productivity", "category": "software", "countries": ["*"],
     "plans": [
         {"label": "Pro", "amount": 10.00, "currency": "USD",
          "cycle": "monthly"},
     ]},
    {"name": "Figma", "origin": "US", "group": "productivity", "category": "software", "countries": ["*"],
     "plans": [
         {"label": "Professional", "amount": 15.00, "currency": "USD",
          "cycle": "monthly"},
     ]},

    # --- Afrique francophone / CEMAC / UEMOA ---
    {"name": "ENEO", "origin": "CM", "category": "energy", "countries": ["CM"]},
    {"name": "Camwater / CDE", "origin": "CM", "category": "water", "countries": ["CM"]},
    {"name": "Orange Cameroun", "origin": "CM", "category": "telecom", "countries": ["CM"]},
    {"name": "MTN Cameroun", "origin": "CM", "category": "telecom", "countries": ["CM"]},
    {"name": "Camtel", "origin": "CM", "category": "telecom", "countries": ["CM"]},
    {"name": "Nexttel", "origin": "CM", "category": "telecom", "countries": ["CM"]},
    {"name": "Yoomee", "origin": "CM", "category": "telecom", "countries": ["CM"]},
    {"name": "CIE", "origin": "CI", "category": "energy", "countries": ["CI"]},
    {"name": "SODECI", "origin": "CI", "category": "water", "countries": ["CI"]},
    {"name": "SENELEC", "origin": "SN", "category": "energy", "countries": ["SN"]},
    {"name": "SDE / SEN'EAU", "origin": "SN", "category": "water", "countries": ["SN"]},
    {"name": "SEEG", "origin": "GA", "category": "energy", "countries": ["GA"]},
    {"name": "CEB", "origin": "TG", "category": "energy", "countries": ["TG", "BJ"]},
    {"name": "SONEDE", "origin": "TN", "category": "water", "countries": ["TN"]},
    {"name": "STEG", "origin": "TN", "category": "energy", "countries": ["TN"]},
    {"name": "JIRAMA", "origin": "MG", "category": "energy", "countries": ["MG"]},
    {"name": "ONEA", "origin": "BF", "category": "water", "countries": ["BF"]},
    {"name": "SONABEL", "origin": "BF", "category": "energy", "countries": ["BF"]},
    {"name": "SENELEC / Orange Sénégal", "origin": "SN", "category": "telecom",
     "countries": ["SN"]},
    {"name": "Moov Africa", "origin": "MA", "category": "telecom",
     "countries": ["BJ", "CI", "TG", "BF", "NE", "GA", "CD"]},
    {"name": "Airtel Africa", "origin": "GB", "category": "telecom",
     "countries": ["GA", "CD", "CG", "MG", "TD", "NE"]},
    {"name": "LYDEC", "origin": "MA", "category": "energy", "countries": ["MA"]},
    {"name": "ONEE", "origin": "MA", "category": "energy", "countries": ["MA"]},
    {"name": "Inwi", "origin": "MA", "category": "telecom", "countries": ["MA"]},
    {"name": "Maroc Telecom", "origin": "MA", "category": "telecom", "countries": ["MA"]},
    {"name": "SONELGAZ", "origin": "DZ", "category": "energy", "countries": ["DZ"]},
    {"name": "ADE", "origin": "DZ", "category": "water", "countries": ["DZ"]},
    {"name": "Mobilis / Djezzy / Ooredoo", "origin": "DZ", "category": "telecom",
     "countries": ["DZ"]},

    # --- Union européenne ---
    {"name": "EDF", "origin": "FR", "category": "energy", "countries": ["FR"]},
    {"name": "Engie", "origin": "FR", "category": "energy", "countries": ["FR", "BE"]},
    {"name": "TotalEnergies", "origin": "FR", "category": "energy", "countries": ["FR", "BE"]},
    {"name": "Orange France", "origin": "FR", "category": "telecom", "countries": ["FR"]},
    {"name": "SFR", "origin": "FR", "category": "telecom", "countries": ["FR"]},
    {"name": "Bouygues Telecom", "origin": "FR", "category": "telecom", "countries": ["FR"]},
    {"name": "Free", "origin": "FR", "category": "telecom", "countries": ["FR"]},
    {"name": "Veolia / Suez (eau)", "origin": "FR", "category": "water", "countries": ["FR"]},
    {"name": "URSSAF", "origin": "FR", "category": "other", "countries": ["FR"]},
    {"name": "Assurance habitation/pro", "category": "insurance",
     "countries": ["FR", "BE", "DE", "ES", "IT"]},
    {"name": "Enel", "origin": "IT", "category": "energy", "countries": ["IT", "ES"]},
    {"name": "Iberdrola", "origin": "ES", "category": "energy", "countries": ["ES"]},
    {"name": "Movistar", "origin": "ES", "category": "telecom", "countries": ["ES"]},
    {"name": "Vodafone", "origin": "GB", "category": "telecom",
     "countries": ["DE", "ES", "IT", "GB", "PT"]},
    {"name": "Telefónica / O2", "origin": "ES", "category": "telecom",
     "countries": ["DE", "ES", "GB"]},
    {"name": "Deutsche Telekom", "origin": "DE", "category": "telecom", "countries": ["DE"]},
    {"name": "Proximus", "origin": "BE", "category": "telecom", "countries": ["BE"]},
    {"name": "KPN", "origin": "NL", "category": "telecom", "countries": ["NL"]},

    # --- Amériques ---
    {"name": "Comcast / Xfinity", "origin": "US", "category": "telecom", "countries": ["US"]},
    {"name": "Verizon", "origin": "US", "category": "telecom", "countries": ["US"]},
    {"name": "AT&T", "origin": "US", "category": "telecom", "countries": ["US"]},
    {"name": "Con Edison", "origin": "US", "category": "energy", "countries": ["US"]},
    {"name": "Hydro-Québec", "origin": "CA", "category": "energy", "countries": ["CA"]},
    {"name": "Bell / Rogers / Telus", "origin": "CA", "category": "telecom",
     "countries": ["CA"]},
    {"name": "CFE", "origin": "MX", "category": "energy", "countries": ["MX"]},
    {"name": "Telcel / Telmex", "origin": "MX", "category": "telecom", "countries": ["MX"]},
    {"name": "Sabesp / eau municipale", "origin": "BR", "category": "water",
     "countries": ["BR"]},
    {"name": "Claro / Vivo", "origin": "BR", "category": "telecom", "countries": ["BR"]},

    # --- Asie ---
    {"name": "Jio / Airtel India", "origin": "IN", "category": "telecom", "countries": ["IN"]},
    {"name": "China Mobile", "origin": "CN", "category": "telecom", "countries": ["CN"]},
    {"name": "PLDT / Globe", "origin": "PH", "category": "telecom", "countries": ["PH"]},
    {"name": "Singtel", "origin": "SG", "category": "telecom", "countries": ["SG"]},
    {"name": "Etisalat / du", "origin": "AE", "category": "telecom", "countries": ["AE"]},
    {"name": "DEWA", "origin": "AE", "category": "energy", "countries": ["AE"]},
]


def flag_emoji(country_code: str | None) -> str:
    """ISO 3166-1 alpha-2 → drapeau emoji (indicateurs régionaux)."""
    code = (country_code or "").upper()
    if len(code) != 2 or not code.isalpha():
        return ""
    return "".join(chr(0x1F1E6 + ord(c) - ord("A")) for c in code)


def provider_origin(name: str | None) -> str | None:
    """Pays d'origine du fournisseur correspondant à `name`.

    Correspondance insensible à la casse, sur le nom complet ou sur
    chaque segment d'une entrée composée (« Orange / Sosh » → « Sosh »).
    Renvoie None si le fournisseur n'est pas dans le catalogue."""
    key = (name or "").strip().lower()
    if not key:
        return None
    for p in CATALOG:
        if key in {part.strip().lower() for part in p["name"].split("/")}:
            return p.get("origin")
    return None


def providers_for(country_code: str) -> list[dict]:
    """Fournisseurs internationaux + ceux du pays demandé.
    `origin` = pays du fournisseur (siège, ou pays d'exploitation
    pour une filiale locale) ; `flag` = son drapeau emoji."""
    code = (country_code or "").upper()
    return [
        {
            "name": p["name"],
            "category": p["category"],
            "group": p.get("group"),
            "origin": p.get("origin"),
            "flag": flag_emoji(p.get("origin")),
            "plans": p.get("plans") or [],
        }
        for p in CATALOG
        if "*" in p["countries"] or code in p["countries"]
    ]
