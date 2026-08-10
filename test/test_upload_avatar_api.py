#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Test python upload avatar to Odoo API /api/v1/mobile/avatar/upload
"""

import urllib.request
import json
import os
import base64

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

print("Token:", token[:10])

# Test small 1x1 pink PNG base64
pink_png_b64 = "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg=="

upload_url = f"{BASE_URL}/api/v1/mobile/avatar/upload"
upload_payload = json.dumps({"avatar": pink_png_b64}).encode("utf-8")
req = urllib.request.Request(
    upload_url,
    data=upload_payload,
    headers={
        "Content-Type": "application/json",
        "Authorization": f"Bearer {token}",
        "User-Agent": "Mozilla/5.0"
    },
    method="POST"
)

try:
    with urllib.request.urlopen(req) as res:
        print("UPLOAD STATUS:", res.status)
        print("RESPONSE:", res.read().decode("utf-8"))
except Exception as e:
    print("UPLOAD ERROR:", e)
