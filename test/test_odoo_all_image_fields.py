#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Inspect all avatar fields for user 3514 and partner 6713 on vuahethong.net
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

fields_to_check = [
    # res.users 3514
    "/web/image/res.users/3514/avatar_1920",
    "/web/image/res.users/3514/image_1920",
    "/web/image/res.users/3514/avatar_512",
    "/web/image/res.users/3514/image_512",
    "/web/image/res.users/3514/avatar_256",
    "/web/image/res.users/3514/image_256",
    "/web/image/res.users/3514/avatar_128",
    "/web/image/res.users/3514/image_128",
    # res.partner 6713
    "/web/image/res.partner/6713/avatar_1920",
    "/web/image/res.partner/6713/image_1920",
    "/web/image/res.partner/6713/avatar_512",
    "/web/image/res.partner/6713/image_512",
    "/web/image/res.partner/6713/avatar_256",
    "/web/image/res.partner/6713/image_256",
    "/web/image/res.partner/6713/avatar_128",
    "/web/image/res.partner/6713/image_128",
    # hr.employee
    "/web/image/hr.employee/3514/avatar_128",
    "/web/image/hr.employee/3514/image_128",
    "/web/image/hr.employee/3514/avatar_1920",
    "/web/image/hr.employee/3514/image_1920",
]

print("--- TESTING ALL IMAGE FIELDS ---")
for f in fields_to_check:
    u = f"{BASE_URL}{f}"
    req = urllib.request.Request(u, headers={"User-Agent": "Mozilla/5.0"})
    try:
        with urllib.request.urlopen(req) as res:
            b = res.read()
            cd = res.headers.get("Content-Disposition", "")
            print(f"📷 {f} -> Size: {len(b)} bytes | CD: {cd}")
    except Exception as e:
        print(f"❌ {f} -> Error: {e}")
