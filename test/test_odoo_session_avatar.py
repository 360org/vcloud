#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Test fetching avatar with Odoo Session Cookie vs JWT Bearer vs Public
"""

import urllib.request
import json
import http.cookiejar

BASE_URL = "https://vuahethong.net"
LOGIN_USER = "tanmnn@360.org.vn"
LOGIN_PASS = "@360.org.vn"

# Setup CookieJar
cj = http.cookiejar.CookieJar()
opener = urllib.request.build_opener(urllib.request.HTTPCookieProcessor(cj))

# 1. Login via /web/session/authenticate to get session_id cookie
auth_url = f"{BASE_URL}/web/session/authenticate"
auth_payload = json.dumps({
    "jsonrpc": "2.0",
    "params": {
        "db": "vuahethong",
        "login": LOGIN_USER,
        "password": LOGIN_PASS
    }
}).encode("utf-8")

req = urllib.request.Request(auth_url, data=auth_payload, headers={"Content-Type": "application/json", "User-Agent": "Mozilla/5.0"}, method="POST")
with opener.open(req) as res:
    resp_data = json.loads(res.read().decode("utf-8"))
    print("SESSION AUTH RESPONSE:")
    print("User ID:", resp_data.get("result", {}).get("uid"))
    print("Partner ID:", resp_data.get("result", {}).get("partner_id"))

cookies = {cookie.name: cookie.value for cookie in cj}
print("Session Cookies:", cookies)

# Test endpoints with Session Cookie
endpoints_to_test = [
    "/web/image/res.users/3514/avatar_1920",
    "/web/image/res.users/3514/image_1920",
    "/web/image/res.users/3514/avatar_128",
    "/web/image/res.users/3514/image_128",
    "/web/image/res.partner/6713/avatar_128",
    "/web/image/res.partner/6713/image_1920",
    "/web/image?model=res.users&id=3514&field=avatar_1920",
    "/web/image?model=res.users&id=3514&field=image_1920",
    "/web/image?model=res.partner&id=6713&field=avatar_128",
]

print("\n--- FETCHING AVATAR WITH ODOO SESSION COOKIE ---")
for ep in endpoints_to_test:
    url = f"{BASE_URL}{ep}"
    req = urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0"})
    try:
        with opener.open(req) as res:
            data = res.read()
            cd = res.headers.get("Content-Disposition", "")
            print(f"📷 {ep} -> Size: {len(data)} bytes | CD: {cd}")
            if len(data) > 7000 and "placeholder" not in cd:
                out_path = "/tmp/real_pink_cat_avatar.png"
                with open(out_path, "wb") as f:
                    f.write(data)
                print(f"   🎉 SUCCESS! FOUND REAL AVATAR! Saved to {out_path}")
    except Exception as e:
        print(f"❌ {ep} -> Error: {e}")
