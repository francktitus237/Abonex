"""Smoke test API — exerce chaque endpoint /api/v1/ et rapporte
les erreurs. Usage : python smoke_test.py (serveur sur :8010)."""
import io
import json
import time
import requests

BASE = "http://127.0.0.1:8010/api/v1"
EMAIL = f"smoke_{int(time.time())}@test.dev"
PW = "TestPass123!"
RESULTS = []


def check(name, r, ok=(200, 201)):
    status = r.status_code
    good = status in ok
    RESULTS.append((name, status, good))
    mark = "OK " if good else "FAIL"
    body = ""
    if not good:
        try:
            body = json.dumps(r.json())[:220]
        except Exception:
            body = r.text[:220]
    print(f"[{mark}] {name:45s} -> {status} {body}")
    return r


def h(tok):
    return {"Authorization": f"Bearer {tok}"}


print("=== AUTH ===")
r = check("register", requests.post(f"{BASE}/auth/register/", json={
    "email": EMAIL, "password": PW, "full_name": "Smoke Test",
}), ok=(200, 201))
tok = None
try:
    tok = r.json().get("access") or r.json().get("tokens", {}).get("access")
except Exception:
    pass
if not tok:
    r = check("login", requests.post(f"{BASE}/auth/login/", json={
        "email": EMAIL, "password": PW}))
    tok = r.json().get("access") or r.json().get("tokens", {}).get("access")
H = h(tok)

check("me", requests.get(f"{BASE}/auth/me/", headers=H))
check("app-version", requests.get(f"{BASE}/meta/app-version/", headers=H))

print("=== WORKSPACE ===")
check("setup->business", requests.patch(f"{BASE}/workspace/setup/", headers=H, json={
    "kind": "business", "name": "SmokeCorp", "country": "CM",
    "default_currency": "XAF", "legal_name": "Smoke SARL",
    "tax_id": "NIU123", "sector": "tech", "size": "tpe",
}))
check("plans", requests.get(f"{BASE}/plans/", headers=H))
check("set plan business", requests.patch(f"{BASE}/workspace/plan/", headers=H,
      json={"plan": "business"}))
check("workspace budget", requests.patch(f"{BASE}/workspace/budget/", headers=H,
      json={"monthly_budget": "500000", "alert_threshold": 80}))

print("=== SUBSCRIPTIONS ===")
r = check("create sub", requests.post(f"{BASE}/subscriptions/", headers=H, json={
    "name": "SmokeNetflix", "provider": "Netflix", "amount": "3500",
    "currency": "XAF", "cycle": "monthly", "next_due_date": "2026-11-20",
    "category": "software",
}))
sub_id = r.json().get("id")
check("list subs", requests.get(f"{BASE}/subscriptions/", headers=H))
check("patch sub", requests.patch(f"{BASE}/subscriptions/{sub_id}/", headers=H,
      json={"amount": "3600"}))
check("bulk subs", requests.post(f"{BASE}/subscriptions/bulk/", headers=H, json={
    "items": [{"name": "SmokeSpotify", "amount": "2500", "currency": "XAF",
               "cycle": "monthly", "next_due_date": "2026-11-22"}]}))
check("history", requests.get(f"{BASE}/subscriptions/{sub_id}/history/", headers=H))
check("add comment", requests.post(f"{BASE}/subscriptions/{sub_id}/comments/",
      headers=H, json={"text": "note de test"}))
check("insights", requests.get(f"{BASE}/insights/", headers=H))

print("=== PAYMENTS ===")
r = check("pending payments", requests.get(f"{BASE}/payments/", headers=H))
items = r.json() if isinstance(r.json(), list) else r.json().get("results", [])
if items:
    pid = items[0]["id"]
    check("payment verdict approve", requests.post(
        f"{BASE}/payments/{pid}/verdict/", headers=H,
        json={"verdict": "approved"}))

print("=== EMPLOYES & PAIE ===")
r = check("create employee", requests.post(f"{BASE}/employees/", headers=H, json={
    "name": "Jean Test", "job_title": "Dev", "salary": "150000",
    "currency": "XAF", "hire_date": "2026-01-15",
}))
emp_id = r.json().get("id")
check("list employees", requests.get(f"{BASE}/employees/", headers=H))
r = check("payroll item", requests.post(f"{BASE}/payroll-items/", headers=H, json={
    "employee": emp_id, "kind": "bonus", "label": "Prime test",
    "amount": "10000", "period": "2026-11",
}))
item_id = r.json().get("id")
check("list payroll items", requests.get(f"{BASE}/payroll-items/", headers=H))
check("payslip pdf", requests.get(
    f"{BASE}/employees/{emp_id}/payslip/?period=2026-11", headers=H))
check("pay all", requests.post(f"{BASE}/employees/pay-all/", headers=H,
      json={"period": "2026-11"}))
check("my payslip (non lie)", requests.get(f"{BASE}/employees/me/payslip/",
      headers=H), ok=(200, 400, 403, 404))
check("delete payroll item", requests.delete(
    f"{BASE}/payroll-items/{item_id}/", headers=H), ok=(200, 204))

print("=== FOURNISSEURS ===")
r = check("create supplier", requests.post(f"{BASE}/suppliers/", headers=H, json={
    "name": "FournTest", "contact": "699001122", "payment_delay_days": 30,
}))
sup_id = r.json().get("id")
check("list suppliers", requests.get(f"{BASE}/suppliers/", headers=H))
check("patch supplier", requests.patch(f"{BASE}/suppliers/{sup_id}/",
      headers=H, json={"contact": "677889900"}))
check("delete supplier", requests.delete(f"{BASE}/suppliers/{sup_id}/",
      headers=H), ok=(200, 204))

print("=== GOUVERNANCE ===")
r = check("create department", requests.post(f"{BASE}/departments/", headers=H,
      json={"name": "IT"}))
dep_id = r.json().get("id")
check("list departments", requests.get(f"{BASE}/departments/", headers=H))
check("create budget", requests.post(f"{BASE}/budgets/", headers=H, json={
    "department": dep_id, "amount": "100000", "currency": "XAF",
    "period": "monthly", "alert_threshold": 80,
}))
check("list budgets", requests.get(f"{BASE}/budgets/", headers=H))
check("treasury", requests.get(f"{BASE}/treasury/?horizon=3", headers=H))
check("audit", requests.get(f"{BASE}/audit/", headers=H))

print("=== WEBHOOKS (plan business) ===")
r = check("create webhook", requests.post(f"{BASE}/webhooks/", headers=H, json={
    "url": "https://example.com/hook", "secret": "s3cret",
    "events": "payment,subscription",
}))
wh_id = r.json().get("id")
check("list webhooks", requests.get(f"{BASE}/webhooks/", headers=H))
check("delete webhook", requests.delete(f"{BASE}/webhooks/{wh_id}/",
      headers=H), ok=(200, 204))

print("=== IMPORT CSV ===")
csv_data = (
    "date;libelle;montant\n"
    "2026-11-08;Netflix abonnement;-3500\n"
    "2026-11-08;Facture inconnue XYZ;-999\n"
).encode("utf-8")
check("import transactions", requests.post(
    f"{BASE}/import/transactions/", headers=H,
    files={"file": ("releve.csv", io.BytesIO(csv_data), "text/csv")}))

print("=== EXPORTS ===")
check("export csv", requests.get(f"{BASE}/export/csv/", headers=H))
check("export xlsx", requests.get(f"{BASE}/export/xlsx/", headers=H))
check("export pdf", requests.get(f"{BASE}/export/pdf/", headers=H))
check("monthly report mail", requests.post(
    f"{BASE}/report/monthly/send/", headers=H, json={}), ok=(200, 202, 500))

print("=== DIVERS ===")
check("users list", requests.get(f"{BASE}/users/", headers=H))
check("memberships", requests.get(f"{BASE}/memberships/", headers=H))
check("rates", requests.get(f"{BASE}/rates/", headers=H))
check("providers catalog", requests.get(f"{BASE}/providers/catalog/", headers=H))
check("connectors", requests.get(f"{BASE}/connectors/", headers=H))
check("connections", requests.get(f"{BASE}/connections/", headers=H))
check("powens login", requests.get(f"{BASE}/connectors/powens/login/",
      headers=H), ok=(200, 400, 502, 503))
check("device token", requests.post(f"{BASE}/devices/", headers=H,
      json={"token": "fcm-test-token", "platform": "android"}),
      ok=(200, 201, 204))

print("=== 2FA ===")
r = check("totp setup", requests.post(f"{BASE}/auth/2fa/setup/", headers=H, json={}))
uri = r.json().get("uri") or r.json().get("otpauth_uri")
if uri:
    import pyotp
    secret = uri.split("secret=")[1].split("&")[0]
    code = pyotp.TOTP(secret).now()
    check("totp enable", requests.post(f"{BASE}/auth/2fa/enable/", headers=H,
          json={"code": code}))
    code2 = pyotp.TOTP(secret).now()
    time.sleep(31)  # nouveau pas de temps pour le code de desactivation
    check("totp disable", requests.post(f"{BASE}/auth/2fa/disable/", headers=H,
          json={"code": pyotp.TOTP(secret).now()}))

print("=== PERMISSIONS NEGATIVES ===")
check("me sans token (401 attendu)", requests.get(f"{BASE}/auth/me/"),
      ok=(401,))
check("subs sans token (401 attendu)", requests.get(f"{BASE}/subscriptions/"),
      ok=(401,))

print()
fails = [x for x in RESULTS if not x[2]]
print(f"==== {len(RESULTS)} appels, {len(fails)} echec(s) ====")
for name, st, _ in fails:
    print(f"  FAIL {name}: {st}")
