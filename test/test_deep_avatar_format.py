#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Unit test "Vặt lá tìm sâu" kiểm tra toàn bộ định dạng ảnh Avatar từ Odoo API.
"""

import unittest
import json
import urllib.request
import os
import struct

BASE_URL = os.environ.get("VCLOUD_ODOO_API_BASE_URL", "https://vuahethong.net")
LOGIN_USER = os.environ.get("ODOO_USER", "tanmnn@360.org.vn")
LOGIN_PASS = os.environ.get("ODOO_PASS", "@360.org.vn")

def get_image_magic(data_bytes):
    if not data_bytes:
        return "EMPTY_BYTES"
    if data_bytes.startswith(b'\x89PNG\r\n\x1a\n'):
        return "PNG"
    if data_bytes.startswith(b'\xff\xd8\xff'):
        return "JPEG"
    if data_bytes.startswith(b'GIF87a') or data_bytes.startswith(b'GIF89a'):
        return "GIF"
    if data_bytes.startswith(b'RIFF') and b'WEBP' in data_bytes[:16]:
        return "WEBP"
    if b'<svg' in data_bytes[:100].lower() or b'<?xml' in data_bytes[:50].lower():
        return "SVG"
    if b'<!DOCTYPE html>' in data_bytes[:100] or b'<html' in data_bytes[:100].lower():
        return "HTML_DOCUMENT (LỖI ĐỊNH DẠNG/PAGE)"
    return f"UNKNOWN_HEX ({data_bytes[:16].hex()})"

class TestDeepAvatarFormat(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
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
            cls.token = res_dict.get("access_token")

    def _get(self, endpoint, is_json=True):
        url = f"{BASE_URL}{endpoint}" if endpoint.startswith('/') else endpoint
        req = urllib.request.Request(
            url,
            headers={"Authorization": f"Bearer {self.token}", "User-Agent": "Mozilla/5.0"},
        )
        with urllib.request.urlopen(req) as res:
            raw = res.read()
            if is_json:
                return json.loads(raw.decode("utf-8"))
            return res.status, dict(res.headers), raw

    def test_inspect_all_avatars(self):
        print("\n==========================================================================")
        print("🔍 1. KIỂM TRA API /api/v1/auth/me (USER THỰC TẾ DÙNG ĐĂNG NHẬP):")
        print("==========================================================================")
        me = self._get("/api/v1/auth/me")
        print(f"UID: {me.get('uid')}")
        print(f"Name: {me.get('name')}")
        print(f"Partner ID: {me.get('partner_id')}")
        print(f"avatar_url field: {me.get('avatar_url')}")
        print(f"image_128_url field: {me.get('image_128_url')}")
        print(f"avatar_128_url field: {me.get('avatar_128_url')}")
        
        # Inspect user avatar content
        user_avatar_target = me.get('avatar_url') or me.get('avatar_128_url') or me.get('image_128_url')
        if user_avatar_target:
            status, headers, content = self._get(user_avatar_target, is_json=False)
            magic = get_image_magic(content)
            print(f"\n👉 KẾT QUẢ TẢI AVATAR USER CÁ NHÂN ({user_avatar_target}):")
            print(f"   Status: {status}")
            print(f"   Content-Type: {headers.get('Content-Type')}")
            print(f"   Size: {len(content)} bytes")
            print(f"   Magic Type: {magic}")
            if len(content) < 1000:
                print(f"   Content Snippet: {content[:200]}")

        print("\n==========================================================================")
        print("🔍 2. KIỂM TRA BẢNG DANH SÁCH RES.USERS VS RES.PARTNER:")
        print("==========================================================================")
        partner_id = me.get('partner_id')
        user_id = me.get('uid')
        
        test_paths = [
            f"/web/image/res.users/{user_id}/avatar_128",
            f"/web/image/res.users/{user_id}/image_128",
            f"/web/image/res.partner/{partner_id}/avatar_128",
            f"/web/image/res.partner/{partner_id}/image_128",
        ]
        
        for path in test_paths:
            try:
                status, headers, content = self._get(path, is_json=False)
                magic = get_image_magic(content)
                print(f"📷 {path} -> HTTP {status} | Type: {headers.get('Content-Type')} | Size: {len(content)}B | Format: {magic}")
            except Exception as e:
                print(f"❌ {path} -> Error: {e}")

        print("\n==========================================================================")
        print("🔍 3. KIỂM TRA THÀNH VIÊN VÀ KÊNH CHAT (CHANNELS & MESSAGES):")
        print("==========================================================================")
        channels = self._get("/api/v1/mobile/chat/channels")
        print(f"Tổng số channels: {len(channels)}")
        for ch in channels[:3]:
            ch_id = ch.get('id')
            ch_name = ch.get('name')
            ch_avatar = ch.get('avatar_url') or ch.get('avatarUrl')
            print(f"\nChannel #{ch_id} [{ch_name}] -> Avatar: {ch_avatar}")
            if ch_avatar:
                try:
                    status, headers, content = self._get(ch_avatar, is_json=False)
                    magic = get_image_magic(content)
                    print(f"   -> HTTP {status} | Size: {len(content)}B | Format: {magic}")
                except Exception as e:
                    print(f"   -> Lỗi fetch: {e}")

if __name__ == "__main__":
    unittest.main()
