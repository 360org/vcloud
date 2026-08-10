#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Script test avatar URL HTTP response, headers, cookies, content-type and redirect.
"""

import json
import urllib.request
import os

BASE_URL = os.environ.get("VCLOUD_ODOO_API_BASE_URL", "https://vuahethong.net")
LOGIN_USER = os.environ.get("ODOO_USER", "tanmnn@360.org.vn")
LOGIN_PASS = os.environ.get("ODOO_PASS", "@360.org.vn")

def main():
    # Login
    url = f"{BASE_URL}/api/v1/mobile/auth/login"
    payload = json.dumps({"login": LOGIN_USER, "password": LOGIN_PASS}).encode("utf-8")
    req = urllib.request.Request(
        url,
        data=payload,
        headers={"Content-Type": "application/json", "User-Agent": "Mozilla/5.0"},
        method="POST",
    )
    with urllib.request.urlopen(req) as res:
        data = json.loads(res.read().decode("utf-8"))
        res_dict = data.get("result", data) if isinstance(data, dict) else data
        token = res_dict.get("access_token")

    print(f"Token: {token[:10]}...")

    test_urls = [
        f"{BASE_URL}/api/v1/mobile/avatar/partners/6360",
        f"{BASE_URL}/api/v1/mobile/avatar/partners/6360?token={token}",
        f"{BASE_URL}/web/image/res.partner/6360/avatar_128",
        f"{BASE_URL}/web/image/res.partner/6360/avatar_128?token={token}",
        f"{BASE_URL}/web/image/res.users/2/avatar_128",
        f"{BASE_URL}/api/v1/mobile/avatar/users/2",
    ]

    print("\n--- TESTING AVATAR URLS WITH NO AUTH HEADERS (SIMULATING Image.network IN BROWSER/FLUTTER) ---")
    for u in test_urls:
        req = urllib.request.Request(u, headers={"User-Agent": "Mozilla/5.0"})
        try:
            with urllib.request.urlopen(req) as res:
                content = res.read()
                print(f"URL: {u}\n  -> Status: {res.status} | Content-Type: {res.headers.get('Content-Type')} | Size: {len(content)} bytes")
        except Exception as e:
            print(f"URL: {u}\n  -> FAILED: {e}")

    print("\n--- TESTING AVATAR URLS WITH Authorization: Bearer {token} ---")
    for u in test_urls:
        req = urllib.request.Request(u, headers={"Authorization": f"Bearer {token}", "User-Agent": "Mozilla/5.0"})
        try:
            with urllib.request.urlopen(req) as res:
                content = res.read()
                print(f"URL: {u}\n  -> Status: {res.status} | Content-Type: {res.headers.get('Content-Type')} | Size: {len(content)} bytes")
        except Exception as e:
            print(f"URL: {u}\n  -> FAILED: {e}")

if __name__ == "__main__":
    main()
