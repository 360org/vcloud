#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Download avatar image from Odoo API /me response and analyze its contents.
"""

import urllib.request
import os

urls = [
    "https://vuahethong.net/web/image/res.users/3514/image_128/128x128",
    "https://vuahethong.net/web/image/res.users/3514/image_512/512x512",
    "https://vuahethong.net/web/image/res.partner/6713/avatar_128/128x128",
    "https://vuahethong.net/web/image/res.partner/6713/image_128",
    "https://vuahethong.net/web/image/res.partner/6713/image_512",
]

for idx, url in enumerate(urls):
    req = urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0"})
    try:
        with urllib.request.urlopen(req) as res:
            data = res.read()
            out_file = f"/tmp/avatar_test_{idx}.png"
            with open(out_file, "wb") as f:
                f.write(data)
            print(f"URL: {url}")
            print(f"  -> Size: {len(data)} bytes, Header Content-Disposition: {res.headers.get('Content-Disposition')}")
            print(f"  -> Saved to {out_file}")
    except Exception as e:
        print(f"URL: {url} -> ERROR: {e}")
