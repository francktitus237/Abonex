"""Chiffrement symétrique des credentials fournisseurs (Fernet).

La clé vient de PROVIDER_SECRET_KEY (.env) — si absente on dérive
une clé de SECRET_KEY pour que le dev fonctionne sans config,
mais en prod il faut définir PROVIDER_SECRET_KEY.
"""
import base64
import hashlib
import os

from cryptography.fernet import Fernet
from django.conf import settings


def _fernet() -> Fernet:
    raw = os.getenv("PROVIDER_SECRET_KEY") or settings.SECRET_KEY
    key = base64.urlsafe_b64encode(
        hashlib.sha256(raw.encode()).digest()
    )
    return Fernet(key)


def encrypt(plaintext: str) -> str:
    return _fernet().encrypt(plaintext.encode()).decode()


def decrypt(token: str) -> str:
    return _fernet().decrypt(token.encode()).decode()
