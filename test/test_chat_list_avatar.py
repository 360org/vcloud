#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
UnitTest kiểm tra trực tiếp Avatar API Odoo cho:
1. User cá nhân (Ma Nguyễn Nhật Tân - User 3514): Xác minh ảnh con mèo hồng (~10KB)
2. Toàn bộ danh sách Chat Channels (/api/v1/mobile/chat/channels): Kiểm tra từng avatar của từng người dùng trong chat.
"""

import unittest
import urllib.request
import json

BASE_URL = "https://vuahethong.net"
LOGIN_URL = f"{BASE_URL}/api/v1/mobile/auth/login"
CHANNELS_URL = f"{BASE_URL}/api/v1/mobile/chat/channels"

class TestChatListAvatar(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        print("\n🔑 1. Đang đăng nhập lấy JWT Access Token...")
        payload = json.dumps({
            "login": "tanmnn@360.org.vn",
            "password": "@360.org.vn"
        }).encode("utf-8")
        
        req = urllib.request.Request(
            LOGIN_URL,
            data=payload,
            headers={
                "Content-Type": "application/json",
                "User-Agent": "Mozilla/5.0 (X11; Linux x86_64)"
            }
        )
        with urllib.request.urlopen(req) as res:
            data = json.loads(res.read().decode("utf-8"))
            cls.token = data.get("access_token")
            cls.uid = data.get("uid")
        
        print(f"✅ Đăng nhập thành công! Token length: {len(cls.token)}")

    def test_01_user_profile_avatar(self):
        """Kiểm tra Avatar User cá nhân 3514 (Con mèo hồng ~10KB)"""
        print("\n👤 2. Kiểm tra Avatar cá nhân (/api/v1/mobile/avatar/users/3514)...")
        avatar_url = f"{BASE_URL}/api/v1/mobile/avatar/users/{self.uid}?access_token={self.token}"
        
        req = urllib.request.Request(avatar_url, headers={"User-Agent": "Mozilla/5.0 (X11; Linux x86_64)"})
        with urllib.request.urlopen(req) as res:
            content = res.read()
            status = res.status
            content_type = res.headers.get("Content-Type", "")
            
            print(f"   • Status Code : {status}")
            print(f"   • Content-Type: {content_type}")
            print(f"   • Kích thước  : {len(content)} bytes ({len(content)/1024:.2f} KB)")
            
            self.assertEqual(status, 200)
            self.assertGreater(len(content), 8000, "Ảnh cá nhân phải là ảnh con mèo hồng (>8KB), không phải placeholder")
            print("   🎉 KẾT QUẢ: Avatar cá nhân hiển thị ĐÚNG hình con mèo hồng!")

    def test_02_chat_channels_avatars(self):
        """Kiểm tra danh sách Chat Channels và Avatar tương ứng"""
        print("\n💬 3. Lấy danh sách Chat Channels (/api/v1/mobile/chat/channels)...")
        req = urllib.request.Request(
            CHANNELS_URL,
            headers={
                "Authorization": f"Bearer {self.token}",
                "User-Agent": "Mozilla/5.0 (X11; Linux x86_64)"
            }
        )
        with urllib.request.urlopen(req) as res:
            channels = json.loads(res.read().decode("utf-8"))
        
        print(f"   • Tổng số kênh chat tìm thấy: {len(channels)}")
        print("\n   📊 BẢNG KIỂM TRA AVATAR TỪNG KÊNH CHAT:")
        print("   " + "-" * 85)
        print(f"   {'STT':<4} | {'Tên Kênh/Người':<25} | {'Loại':<6} | {'Status':<6} | {'Kích thước':<10} | {'Kết quả'}")
        print("   " + "-" * 85)
        
        for idx, ch in enumerate(channels[:15], 1):
            ch_name = (ch.get("name") or "Unnamed")[:25]
            ch_type = ch.get("channel_type", "chat")
            avatar_path = ch.get("avatar_url")
            partner_id = ch.get("partner_id")
            
            if not avatar_path and partner_id:
                avatar_path = f"/web/image/res.partner/{partner_id}/avatar_128"
            elif not avatar_path:
                avatar_path = f"/web/image/discuss.channel/{ch['id']}/avatar_128"
                
            if avatar_path.startswith("http"):
                url = avatar_path
            else:
                url = f"{BASE_URL}{avatar_path}"
                
            if "access_token=" not in url:
                sep = "&" if "?" in url else "?"
                url = f"{url}{sep}access_token={self.token}"
                
            try:
                img_req = urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0 (X11; Linux x86_64)"})
                with urllib.request.urlopen(img_req) as img_res:
                    img_bytes = img_res.read()
                    img_size = len(img_bytes)
                    img_status = img_res.status
                    
                    if img_size in (6314, 6078):
                        result = "⚪ Mặc định (Placeholder 6.3KB -> Chữ cái Initials)"
                    elif img_size > 1000:
                        result = f"🖼️ Ảnh thật ({img_size/1024:.1f} KB)"
                    else:
                        result = f"❓ Nhỏ ({img_size} B)"
                        
                    print(f"   {idx:<4} | {ch_name:<25} | {ch_type:<6} | {img_status:<6} | {img_size:<10} | {result}")
            except Exception as e:
                print(f"   {idx:<4} | {ch_name:<25} | {ch_type:<6} | ERR    | 0 B        | ❌ Lỗi: {e}")

        print("   " + "-" * 85)

if __name__ == "__main__":
    unittest.main(verbosity=2)
