#!/usr/bin/env python3
# -*- coding: utf-8 -*-
import urllib.request

urls = [
    "https://vuahethong.net/web/image/res.partner/3514/avatar_128",
    "https://vuahethong.net/web/image/res.users/3514/avatar_128",
    "https://vuahethong.net/web/image/res.partner/6360/avatar_128",
]

for u in urls:
    req = urllib.request.Request(u, headers={"User-Agent": "Mozilla/5.0"})
    try:
        with urllib.request.urlopen(req) as res:
            b = res.read()
            print(f"✅ {u} -> Status: {res.status}, Size: {len(b)} bytes, Type: {res.headers.get('Content-Type')}")
    except Exception as e:
        print(f"❌ {u} -> {e}")
