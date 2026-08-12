#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
UnitTest kiểm tra trực tiếp Avatar người dùng tải từ Odoo API.
Xác minh xem API trả về ảnh thật trên Server (Con mèo hồng ~10KB) hay ảnh mặc định (Placeholder ~6.3KB).
"""

import unittest
import json
import urllib.request
import os

BASE_URL = "https://vuahethong.net"
LOGIN_USER = "tanmnn@360.org.vn"
LOGIN_PASS = "@360.org.vn"

class TestAvatarVerification(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        print("\n🔑 1. Đang đăng nhập lấy JWT Access Token...")
        login_url = f"{BASE_URL}/api/v1/mobile/auth/login"
        payload = json.dumps({"login": LOGIN_USER, "password": LOGIN_PASS}).encode("utf-8")
        req = urllib.request.Request(
            login_url,
            data=payload,
            headers={"Content-Type": "application/json", "User-Agent": "Mozilla/5.0"},
            method="POST"
        )
        with urllib.request.urlopen(req) as res:
            data = json.loads(res.read().decode("utf-8"))
            res_dict = data.get("result", data) if isinstance(data, dict) else data
            cls.token = res_dict.get("access_token")
            cls.uid = res_dict.get("uid") or 3514
            print(f"✅ Đăng nhập thành công! User ID: {cls.uid}")

    def test_fetch_user_profile_and_avatar(self):
        print("\n📡 2. Gọi API /api/v1/auth/me lấy Profile & Avatar URL...")
        me_url = f"{BASE_URL}/api/v1/auth/me"
        req = urllib.request.Request(
            me_url,
            headers={"Authorization": f"Bearer {self.token}", "User-Agent": "Mozilla/5.0"}
        )
        with urllib.request.urlopen(req) as res:
            me_data = json.loads(res.read().decode("utf-8"))
            print(f"   Name: {me_data.get('name')}")
            print(f"   User ID: {me_data.get('uid')}")
            print(f"   Partner ID: {me_data.get('partner_id')}")

        print("\n🖼️ 3. Tải file ảnh Avatar thực tế từ Endpoint Mobile API...")
        avatar_endpoint = f"{BASE_URL}/api/v1/mobile/avatar/users/{self.uid}?access_token={self.token}"
        req_img = urllib.request.Request(avatar_endpoint, headers={"User-Agent": "Mozilla/5.0"})
        
        with urllib.request.urlopen(req_img) as res_img:
            img_data = res_img.read()
            status_code = res_img.status
            content_type = res_img.headers.get("Content-Type")
            disposition = res_img.headers.get("Content-Disposition", "")
            img_size = len(img_data)

            # Lưu ảnh ra đĩa để kiểm tra trực quan
            save_path = "/tmp/actual_server_avatar.png"
            with open(save_path, "wb") as f:
                f.write(img_data)

            print("\n========================================================")
            print("📊 KẾT QUẢ TẢI AVATAR TỪ SERVER:")
            print("========================================================")
            print(f"  • Endpoint URL     : {avatar_endpoint[:60]}...")
            print(f"  • HTTP Status Code : {status_code}")
            print(f"  • Content-Type     : {content_type}")
            print(f"  • File Header      : {disposition}")
            print(f"  • Kích thước File  : {img_size} bytes ({img_size / 1024:.2f} KB)")
            print(f"  • Đã lưu file tại  : {save_path}")
            print("========================================================")

            # Kiểm tra định dạng ảnh (JPEG/PNG)
            is_jpeg = img_data.startswith(b'\xff\xd8\xff')
            is_png = img_data.startswith(b'\x89PNG\r\n\x1a\n')
            self.assertTrue(is_jpeg or is_png, "Lỗi: File tải về không phải là định dạng ảnh hợp lệ (JPEG/PNG)!")

            # Kiểm tra xem có phải ảnh mặc định placeholder (6.3KB) hay ảnh thật (>9KB)
            is_placeholder = (img_size == 6314) or ("placeholder" in disposition.lower())
            
            if is_placeholder:
                print("❌ KẾT QUẢ: Đây là ảnh mặc định (Placeholder/MT)!")
            else:
                print("🎉 KẾT QUẢ RỰC RỠ: Đã tải THÀNH CÔNG ảnh đại diện thật từ Server (Hình con mèo hồng)!")

            self.assertFalse(is_placeholder, "API trả về ảnh mặc định (Placeholder) thay vì ảnh thật trên Server!")
            self.assertGreater(img_size, 9000, "Kích thước ảnh nhỏ hơn 9KB (không phải ảnh con mèo hồng)!")

if __name__ == "__main__":
    unittest.main()
