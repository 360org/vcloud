#!/usr/bin/env python3
"""
App Store Distribution & Auto-Submit Tool for Vcloud iOS
Part of 360 CORP / Vcloud CI/CD Automation.

Chức năng:
1. Đọc version + build number từ pubspec.yaml (SSOT).
2. Tự động kết nối App Store Connect REST API qua Team Key ES256.
3. Tạo mới hoặc cập nhật version (PREPARE_FOR_SUBMISSION) trên tab Distribution.
4. Tìm và gắn Build ID tương ứng từ TestFlight vào phiên bản.
5. Cập nhật Release Notes ("What's New") đa ngôn ngữ (vi, en-US).
6. Tự động gửi duyệt Apple Review (Review Submissions API).

Sử dụng:
    python3 scripts/appstore_distribute_and_submit.py
    python3 scripts/appstore_distribute_and_submit.py --version 2.9.22 --build 167
    python3 scripts/appstore_distribute_and_submit.py --no-submit
"""

import os
import sys
import time
import argparse
import re
from pathlib import Path

try:
    import jwt
    import requests
except ImportError:
    print("❌ Lỗi: Cần cài đặt thư viện 'pyjwt', 'requests', 'cryptography'.")
    print("   Chạy: pip install pyjwt requests cryptography")
    sys.exit(1)

# Default Configurations
KEY_ID = os.getenv("APP_STORE_CONNECT_KEY_ID", "3J68D9JX79")
ISSUER_ID = os.getenv("APP_STORE_CONNECT_ISSUER_ID", "69a6de93-488c-47e3-e053-5b8c7c11a4d1")
DEFAULT_KEY_PATHS = [
    Path("/media/tanma/DATA/save/file_ios_p8/AuthKey_3J68D9JX79.p8"),
    Path("/media/tanma/DATA/dowloads/AuthKey_3J68D9JX79.p8"),
    Path.home() / ".appstoreconnect" / "private_keys" / f"AuthKey_{KEY_ID}.p8"
]
APP_ID = "1365622472"  # com.w360s.wcloudapp
BASE_URL = "https://api.appstoreconnect.apple.com/v1"

def find_key_file():
    for p in DEFAULT_KEY_PATHS:
        if p.is_file():
            return p
    return None

def get_version_from_pubspec(repo_dir: Path):
    pubspec = repo_dir / "pubspec.yaml"
    if not pubspec.is_file():
        pubspec = repo_dir / "vclients" / "pubspec.yaml"
    if pubspec.is_file():
        content = pubspec.read_text(encoding="utf-8")
        match = re.search(r"^version:\s*([0-9\.]+)\+([0-9]+)", content, re.M)
        if match:
            return match.group(1), match.group(2)
    return "2.9.22", "167"

def get_release_notes(repo_dir: Path, version: str):
    changelog = repo_dir / "docs" / "CHANGELOGS.md"
    if not changelog.is_file():
        changelog = repo_dir / "vclients" / "docs" / "CHANGELOGS.md"
    if changelog.is_file():
        content = changelog.read_text(encoding="utf-8")
        # Extract title line for version
        match = re.search(rf"##\s*\[v?{re.escape(version)}[^\]]*\]\s*—\s*[0-9\-]+\s*\((.*?)\)", content)
        if match:
            return f"Cập nhật {match.group(1).strip()}."
    return "Cập nhật Clean Architecture cho Chat V2, tối ưu luồng đăng ký tài khoản mobile và nâng cao hiệu năng."

def generate_jwt(key_path: Path):
    with open(key_path, "r", encoding="utf-8") as f:
        private_key = f.read()
    now = int(time.time())
    payload = {
        "iss": ISSUER_ID,
        "exp": now + 20 * 60,
        "aud": "appstoreconnect-v1"
    }
    headers = {
        "alg": "ES256",
        "kid": KEY_ID,
        "typ": "JWT"
    }
    return jwt.encode(payload, private_key, algorithm="ES256", headers=headers)

class AppStoreConnectClient:
    def __init__(self, key_path: Path):
        self.key_path = key_path

    def request(self, method: str, endpoint: str, payload=None, params=None):
        token = generate_jwt(self.key_path)
        headers = {
            "Authorization": f"Bearer {token}",
            "Content-Type": "application/json"
        }
        url = f"{BASE_URL}{endpoint}" if endpoint.startswith("/") else f"{BASE_URL}/{endpoint}"
        return requests.request(method, url, headers=headers, json=payload, params=params)

def run_distribution_and_submit(target_version: str, target_build: str, notes: str, auto_submit: bool):
    key_path = find_key_file()
    if not key_path:
        print(f"❌ Không tìm thấy file private key AuthKey_{KEY_ID}.p8")
        sys.exit(1)

    print(f"🔑 Kết nối App Store Connect API (Key ID: {KEY_ID})")
    print(f"🎯 Phiên bản đích: {target_version} (Build: {target_build})")
    print(f"📝 Ghi chú phát hành: {notes}")
    client = AppStoreConnectClient(key_path)

    # 1. Tra cứu danh sách versions
    resp = client.request("GET", f"/apps/{APP_ID}/appStoreVersions", params={"filter[platform]": "IOS"})
    if resp.status_code != 200:
        print(f"❌ Lỗi truy vấn phiên bản: {resp.status_code} {resp.text}")
        return False

    versions = resp.json().get("data", [])
    active_version_id = None
    target_version_obj = None
    editable_version = None

    for v in versions:
        v_str = v["attributes"]["versionString"]
        v_state = v["attributes"]["appStoreState"]
        if v_str == target_version:
            target_version_obj = v
        if v_state in ["PREPARE_FOR_SUBMISSION", "DEVELOPER_REJECTED", "REJECTED"]:
            editable_version = v

    if target_version_obj:
        active_version_id = target_version_obj["id"]
        print(f"ℹ️ Phiên bản {target_version} đã tồn tại (ID: {active_version_id}, Trạng thái: {target_version_obj['attributes']['appStoreState']})")
    elif editable_version:
        active_version_id = editable_version["id"]
        old_str = editable_version["attributes"]["versionString"]
        print(f"🔄 Đổi số hiệu phiên bản đang sửa từ {old_str} thành {target_version}...")
        patch_payload = {
            "data": {
                "id": active_version_id,
                "type": "appStoreVersions",
                "attributes": {"versionString": target_version}
            }
        }
        patch_resp = client.request("PATCH", f"/appStoreVersions/{active_version_id}", payload=patch_payload)
        if patch_resp.status_code not in [200, 201]:
            print(f"⚠️ Đổi số hiệu thất bại: {patch_resp.status_code} {patch_resp.text}")
        else:
            print(f"✅ Đã cập nhật số hiệu phiên bản sang {target_version}")
    else:
        print(f"🚀 Tạo mới phiên bản App Store {target_version} cho nền tảng iOS...")
        create_payload = {
            "data": {
                "type": "appStoreVersions",
                "attributes": {
                    "platform": "IOS",
                    "versionString": target_version
                },
                "relationships": {
                    "app": {"data": {"type": "apps", "id": APP_ID}}
                }
            }
        }
        create_resp = client.request("POST", "/appStoreVersions", payload=create_payload)
        if create_resp.status_code not in [200, 201]:
            print(f"❌ Không thể tạo phiên bản {target_version}: {create_resp.status_code} {create_resp.text}")
            return False
        active_version_id = create_resp.json()["data"]["id"]
        print(f"✅ Đã tạo thành công phiên bản {target_version} (ID: {active_version_id})")

    # 2. Tìm Build từ TestFlight
    print(f"🔍 Tra cứu Build {target_build} trên App Store Connect...")
    build_resp = client.request("GET", "/builds", params={
        "filter[app]": APP_ID,
        "filter[version]": target_build,
        "sort": "-uploadedDate"
    })
    build_id = None
    if build_resp.status_code == 200:
        builds = build_resp.json().get("data", [])
        for b in builds:
            if b["attributes"]["processingState"] == "VALID":
                build_id = b["id"]
                break

    if not build_id:
        print(f"❌ Không tìm thấy Build {target_build} ở trạng thái VALID.")
        return False
    print(f"📦 Đã tìm thấy Build ID: {build_id} (Build {target_build})")

    # 3. Gắn Build vào Version
    print(f"🔗 Gán Build {target_build} vào phiên bản {target_version}...")
    attach_payload = {
        "data": {
            "type": "builds",
            "id": build_id
        }
    }
    attach_resp = client.request("PATCH", f"/appStoreVersions/{active_version_id}/relationships/build", payload=attach_payload)
    if attach_resp.status_code in [200, 204]:
        print(f"🎉 Gán Build {target_build} vào phiên bản {target_version} thành công!")
    else:
        print(f"⚠️ Kết quả gán build: {attach_resp.status_code} {attach_resp.text}")

    # 4. Cập nhật Release Notes (Whats New)
    print("📝 Cập nhật mô tả phát hành (What's New)...")
    loc_resp = client.request("GET", f"/appStoreVersions/{active_version_id}/appStoreVersionLocalizations")
    if loc_resp.status_code == 200:
        for loc in loc_resp.json().get("data", []):
            loc_id = loc["id"]
            locale = loc["attributes"]["locale"]
            patch_loc = {
                "data": {
                    "id": loc_id,
                    "type": "appStoreVersionLocalizations",
                    "attributes": {"whatsNew": notes}
                }
            }
            res = client.request("PATCH", f"/appStoreVersionLocalizations/{loc_id}", payload=patch_loc)
            if res.status_code in [200, 201]:
                print(f"   ✅ Đã cập nhật What's New cho ngôn ngữ '{locale}'")

    # 5. Tự động gửi duyệt (Review Submissions API)
    if not auto_submit:
        print("ℹ️ Bỏ qua bước gửi duyệt theo tùy chọn (--no-submit).")
        return True

    print("\n🚀 Bắt đầu quy trình gửi duyệt tự động lên Apple Review...")
    sub_resp = client.request("GET", f"/apps/{APP_ID}/reviewSubmissions", params={"filter[platform]": "IOS"})
    submission_id = None
    if sub_resp.status_code == 200:
        for s in sub_resp.json().get("data", []):
            state = s["attributes"]["state"]
            if state in ["READY_FOR_REVIEW", "COMPLETING"]:
                submission_id = s["id"]
                break

    if not submission_id:
        create_sub_payload = {
            "data": {
                "type": "reviewSubmissions",
                "attributes": {"platform": "IOS"},
                "relationships": {"app": {"data": {"type": "apps", "id": APP_ID}}}
            }
        }
        res = client.request("POST", "/reviewSubmissions", payload=create_sub_payload)
        if res.status_code in [200, 201]:
            submission_id = res.json()["data"]["id"]
            print(f"✅ Đã tạo Review Submission mới: {submission_id}")
        else:
            print(f"⚠️ Tạo review submission thất bại: {res.status_code} {res.text}")
            return False

    # Thêm item version vào submission
    items_resp = client.request("GET", f"/reviewSubmissions/{submission_id}/items")
    has_item = False
    if items_resp.status_code == 200:
        if len(items_resp.json().get("data", [])) > 0:
            has_item = True

    if not has_item:
        add_item_payload = {
            "data": {
                "type": "reviewSubmissionItems",
                "relationships": {
                    "reviewSubmission": {"data": {"type": "reviewSubmissions", "id": submission_id}},
                    "appStoreVersion": {"data": {"type": "appStoreVersions", "id": active_version_id}}
                }
            }
        }
        res = client.request("POST", "/reviewSubmissionItems", payload=add_item_payload)
        if res.status_code in [200, 201]:
            print(f"✅ Đã thêm Version {target_version} vào đợt gửi duyệt.")
        else:
            print(f"⚠️ Thêm item vào đợt duyệt thất bại: {res.status_code} {res.text}")

    # Gửi duyệt chính thức
    submit_payload = {
        "data": {
            "id": submission_id,
            "type": "reviewSubmissions",
            "attributes": {"submitted": True}
        }
    }
    final_resp = client.request("PATCH", f"/reviewSubmissions/{submission_id}", payload=submit_payload)
    if final_resp.status_code in [200, 201]:
        state = final_resp.json()["data"]["attributes"]["state"]
        print(f"\n🎉 THÀNH CÔNG RỰC RỠ! Phiên bản {target_version} (Build {target_build}) đã gửi duyệt Apple!")
        print(f"   Trạng thái hiện tại: {state} (Waiting for Review)")
        return True
    else:
        print(f"⚠️ Lỗi gửi duyệt: {final_resp.status_code} {final_resp.text}")
        return False

def main():
    repo_root = Path(__file__).resolve().parent.parent
    default_version, default_build = get_version_from_pubspec(repo_root)
    default_notes = get_release_notes(repo_root, default_version)

    parser = argparse.ArgumentParser(description="App Store Distribution & Auto-Submit Tool")
    parser.add_argument("--version", default=default_version, help=f"Phiên bản App Store (mặc định: {default_version})")
    parser.add_argument("--build", default=default_build, help=f"Số hiệu Build TestFlight (mặc định: {default_build})")
    parser.add_argument("--notes", default=default_notes, help="Nội dung What's New phát hành")
    parser.add_argument("--no-submit", action="store_true", help="Chỉ tạo version và gán build, không gửi duyệt Apple")

    args = parser.parse_args()
    success = run_distribution_and_submit(
        target_version=args.version,
        target_build=args.build,
        notes=args.notes,
        auto_submit=not args.no_submit
    )
    sys.exit(0 if success else 1)

if __name__ == "__main__":
    main()
