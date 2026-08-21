#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Test CORS headers on https://vuahethong.net/web/image/res.users/3514/avatar_128
"""

import urllib.request

url = "https://vuahethong.net/web/image/res.users/3514/avatar_128"
req = urllib.request.Request(
    url,
    headers={
        "User-Agent": "Mozilla/5.0",
        "Origin": "http://localhost:8088",
        "Access-Control-Request-Method": "GET"
    }
)

try:
    with urllib.request.urlopen(req) as res:
        print("STATUS:", res.status)
        print("HEADERS:")
        for k, v in res.headers.items():
            print(f"  {k}: {v}")
except Exception as e:
    print("ERROR:", e)
