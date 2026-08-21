#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Unit test kiểm tra Avatar payload trong API Chat channels & messages.
"""

import unittest
import json
import urllib.request
import os

BASE_URL = os.environ.get("VCLOUD_ODOO_API_BASE_URL", "https://vuahethong.net")
LOGIN_USER = os.environ.get("ODOO_USER", "tanmnn@360.org.vn")
LOGIN_PASS = os.environ.get("ODOO_PASS", "@360.org.vn")

class TestChatAvatarAPI(unittest.TestCase):
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

    def _get(self, endpoint):
        url = f"{BASE_URL}{endpoint}"
        req = urllib.request.Request(
            url,
            headers={"Authorization": f"Bearer {self.token}", "User-Agent": "Mozilla/5.0"},
        )
        with urllib.request.urlopen(req) as res:
            return json.loads(res.read().decode("utf-8"))

    def test_inspect_chat_avatars(self):
        print("\n==========================================================================")
        print("🔍 KIỂM TRA PAYLOAD CHAT CHANNELS & MESSAGES AVATARS:")
        print("==========================================================================")
        
        channels_res = self._get("/api/v1/mobile/chat/channels")
        channels = channels_res if isinstance(channels_res, list) else channels_res.get("channels", [])
        
        target_ch = None
        for ch in channels:
            name = ch.get("name", "")
            if "Ngọc Trâm" in name or "Bgreen" in name:
                target_ch = ch
                break
        if not target_ch and channels:
            target_ch = channels[0]
            
        self.assertIsNotNone(target_ch, "Không tìm thấy channel nào")
        ch_id = target_ch.get('id')
        
        msgs_res = self._get(f"/api/v1/mobile/chat/channels/{ch_id}/messages")
        messages = msgs_res.get("messages", []) if isinstance(msgs_res, dict) else msgs_res
        
        print(f"\n--- VERIFYING AVATAR URLS FOR AUTHORS IN CHANNEL {ch_id} ---")
        author_ids = set()
        for msg in messages:
            aid = msg.get("author_id")
            if aid:
                author_ids.add(aid)
                
        print(f"Danh sách Author IDs trong channel: {author_ids}")
        for aid in author_ids:
            avatar_url = f"{BASE_URL}/web/image/res.partner/{aid}/avatar_128"
            req = urllib.request.Request(
                avatar_url,
                headers={"Authorization": f"Bearer {self.token}", "User-Agent": "Mozilla/5.0"},
            )
            try:
                with urllib.request.urlopen(req) as res:
                    status = res.status
                    content_type = res.headers.get("Content-Type", "")
                    content_len = len(res.read())
                    print(f"✅ Author ID {aid} -> HTTP {status} | Type: {content_type} | Size: {content_len} bytes | URL: {avatar_url}")
            except Exception as e:
                print(f"❌ Author ID {aid} -> Lỗi: {e}")

if __name__ == "__main__":
    unittest.main()
