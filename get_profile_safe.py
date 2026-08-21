#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Helper script to fetch Odoo user profile and contact details safely.
Reads credentials from environment variables (ODOO_USER, ODOO_PASS).
"""

import os
import sys
import json
import ssl
import urllib.request
import urllib.error

def fetch_odoo_profile():
    user = os.getenv("ODOO_USER")
    password = os.getenv("ODOO_PASS")

    if not user or not password:
        print("❌ Lỗi: Chưa thiết lập biến môi trường ODOO_USER hoặc ODOO_PASS.")
        sys.exit(1)

    master_url = os.getenv("ODOO_MASTER_URL", "https://vuahethong.net")
    login_endpoint = f"{master_url.rstrip('/')}/api/v1/mobile/auth/login"
    
    payload = {"login": user, "password": password}
    common_headers = {
        "Content-Type": "application/json",
        "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64)"
    }
    ctx = ssl.create_default_context()

    print("🔑 Bước 1: Đang đăng nhập...")
    req = urllib.request.Request(login_endpoint, data=json.dumps(payload).encode("utf-8"), headers=common_headers, method="POST")

    try:
        with urllib.request.urlopen(req, context=ctx) as response:
            res_data = json.loads(response.read().decode("utf-8"))
            result = res_data.get("result", res_data)
            token = result.get("access_token")
            tenant_base_url = result.get("base_url", master_url).rstrip('/')
            
            if not token:
                print("❌ Không nhận được access_token.")
                return

            print("✅ Đăng nhập thành công!")
            me_endpoint = f"{tenant_base_url}/api/v1/auth/me"
            print(f"📡 Bước 2: Tải thông tin hồ sơ cá nhân từ {me_endpoint}...")
            
            me_headers = {**common_headers, "Authorization": f"Bearer {token}"}
            me_req = urllib.request.Request(me_endpoint, headers=me_headers, method="GET")
            
            with urllib.request.urlopen(me_req, context=ctx) as me_res:
                profile_data = json.loads(me_res.read().decode("utf-8"))
                print("\n========================================================")
                print("📊 DỮ LIỆU HỒ SƠ CÁ NHÂN (/api/v1/auth/me):")
                print("========================================================")
                print(json.dumps(profile_data, indent=2))
                print("========================================================")

    except urllib.error.HTTPError as e:
        print(f"❌ Lỗi HTTP: {e.code} - {e.reason}")
    except Exception as e:
        print(f"❌ Lỗi hệ thống: {e}")

if __name__ == "__main__":
    fetch_odoo_profile()
