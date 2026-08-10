#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Test avatar controller endpoints in v_mobile
"""

import urllib.request

urls = [
    "https://vuahethong.net/api/v1/mobile/avatar/users/3514",
    "https://vuahethong.net/api/v1/mobile/avatar/partners/6713",
    "https://vuahethong.net/api/v1/mobile/avatar/channels/4255",
]

for u in urls:
    req = urllib.request.Request(
        u,
        headers={"User-Agent": "Mozilla/5.0", "Origin": "http://localhost:8088"}
    )
    try:
        with urllib.request.urlopen(req) as res:
            data = res.read()
            print(f"✅ {u} -> Status: {res.status}, Type: {res.headers.get('Content-Type')}, Size: {len(data)}B, CORS: {res.headers.get('Access-Control-Allow-Origin')}")
    except Exception as e:
        print(f"❌ {u} -> Error: {e}")
