#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Test python to check if adding token= to /web/image/ URLs breaks Odoo avatar requests.
"""

import urllib.request
import json

BASE_URL = "https://vuahethong.net"
LOGIN_USER = "tanmnn@360.org.vn"
LOGIN_PASS = "@360.org.vn"

# Login
url = f"{BASE_URL}/api/v1/mobile/auth/login"
payload = json.dumps({"login": LOGIN_USER, "password": LOGIN_PASS}).encode("utf-8")
req = urllib.request.Request(url, data=payload, headers={"Content-Type": "application/json", "User-Agent": "Mozilla/5.0"}, method="POST")
with urllib.request.urlopen(req) as res:
    data = json.loads(res.read().decode("utf-8"))
    res_dict = data.get("result", data) if isinstance(data, dict) else data
    token = res_dict.get("access_token")

# Check user profile
req = urllib.request.Request(f"{BASE_URL}/api/v1/mobile/auth/me", headers={"Authorization": f"Bearer {token}", "User-Agent": "Mozilla/5.0"})
with urllib.request.urlopen(req) as res:
    user_me = json.loads(res.read().decode("utf-8"))
    print("USER ME RESPONSE:")
    print(json.dumps(user_me, ensure_ascii=False, indent=2))

user_id = user_me.get("id") or user_me.get("user", {}).get("id")
partner_id = user_me.get("partner_id") or user_me.get("user", {}).get("partner_id")
user_avatar = user_me.get("avatar_url") or user_me.get("user", {}).get("avatar_url")

print(f"\nUser ID: {user_id}, Partner ID: {partner_id}, Avatar URL in /me: {user_avatar}")

urls_to_test = [
    # Clean URLs
    f"{BASE_URL}/web/image/res.partner/6360/avatar_128",
    f"{BASE_URL}/web/image/res.users/{user_id}/avatar_128" if user_id else None,
    f"{BASE_URL}/web/image/res.partner/{partner_id}/avatar_128" if partner_id else None,
    # URLs with token appended
    f"{BASE_URL}/web/image/res.partner/6360/avatar_128?token={token}",
]

print("\n--- TESTING URLS ---")
for u in urls_to_test:
    if not u: continue
    req = urllib.request.Request(u, headers={"User-Agent": "Mozilla/5.0"})
    try:
        with urllib.request.urlopen(req) as res:
            data_bytes = res.read()
            print(f"✅ URL: {u}\n   Status: {res.status} | Content-Type: {res.headers.get('Content-Type')} | Size: {len(data_bytes)}")
    except Exception as e:
        print(f"❌ URL: {u}\n   Error: {e}")
