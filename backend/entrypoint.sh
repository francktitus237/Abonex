#!/bin/sh
set -eu

if [ -n "${POSTGRES_HOST:-}" ]; then
  echo "Attente de PostgreSQL..."
  python - <<'PY'
import os
import socket
import time

host = os.environ.get("POSTGRES_HOST", "db")
port = int(os.environ.get("POSTGRES_PORT", "5432"))
for attempt in range(60):
    try:
        with socket.create_connection((host, port), timeout=2):
            break
    except OSError:
        if attempt == 59:
            raise
        time.sleep(1)
PY
fi

python manage.py migrate --noinput
if [ "${DEMO_SEED_ENABLED:-false}" = "true" ]; then
  python manage.py seed --regional-demo
fi
python manage.py collectstatic --noinput

exec "$@"
