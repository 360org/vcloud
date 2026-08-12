#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Script tải và lưu file ảnh đại diện thật từ Odoo Server cho các người dùng:
- Huy Erp (User 3429)
- Ngọc Trâm Bgreen (User 3425)
- Lê Trung Thuận (User 3441)
- Bắc Đại Bàng (User 3518)
- Hạnh Quyên (User 3339)
- Chau, Le Ba (User 2)
- Ma Nguyễn Nhật Tân (User 3514)
"""

import urllib.request
import json
import os

BASE_URL = "https://vuahethong.net"
LOGIN_URL = f"{BASE_URL}/api/v1/mobile/auth/login"

def main():
    print("\n🔑 1. Đang đăng nhập Odoo API...")
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
        token = data.get("access_token")

    print("✅ Đăng nhập thành công! Đang tải file ảnh đại diện từ Server...\n")

    users_to_check = [
        ("Huy Erp", 3429, "huy_erp.png"),
        ("Ngọc Trâm Bgreen", 3425, "ngoc_tram.png"),
        ("Lê Trung Thuận", 3441, "le_trung_thuan.png"),
        ("Bắc Đại Bàng", 3518, "bac_dai_bang.png"),
        ("Hạnh Quyên", 3339, "hanh_quyen.png"),
        ("Chau, Le Ba", 2, "chau_le_ba.png"),
        ("Ma Nguyễn Nhật Tân", 3514, "nhat_tan.png"),
    ]

    print("=" * 80)
    print(f"{'Tên Người Dùng':<22} | {'User ID':<8} | {'Status':<6} | {'Kích thước':<10} | {'Đường dẫn lưu file ảnh'}")
    print("=" * 80)

    output_dir = "/tmp/odoo_user_avatars"
    os.makedirs(output_dir, exist_ok=True)

    for name, uid, filename in users_to_check:
        avatar_url = f"{BASE_URL}/api/v1/mobile/avatar/users/{uid}?access_token={token}"
        img_req = urllib.request.Request(
            avatar_url,
            headers={"User-Agent": "Mozilla/5.0 (X11; Linux x86_64)"}
        )
        
        try:
            with urllib.request.urlopen(img_req) as img_res:
                content = img_res.read()
                save_path = os.path.join(output_dir, filename)
                with open(save_path, "wb") as f:
                    f.write(content)
                
                size_str = f"{len(content)/1024:.1f} KB"
                print(f"{name:<22} | {uid:<8} | {img_res.status:<6} | {size_str:<10} | {save_path}")
        except Exception as e:
            print(f"{name:<22} | {uid:<8} | ERR    | 0 B        | ❌ Lỗi: {e}")

    print("=" * 80)
    print(f"\n🎉 Tất cả ảnh đã được lưu vào thư mục: {output_dir}")

if __name__ == "__main__":
    main()
