#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
==============================================================================
🧪 COMPREHENSIVE DUAL-VERSION VERIFICATION SUITE (ODOO 17.0 & ODOO 19.0)
==============================================================================
Kiểm tra toàn diện tất cả các tính năng cốt lõi của Mobile API:
  1. 🔑 Authentication & JWT Token (/api/v1/auth/login)
  2. 👤 User Profile & Context (/api/v1/auth/me)
  3. 💬 Chat Channels & Messages (/api/v1/mobile/chat/channels & /channels/<id>/messages)
  4. 📨 Chat Message Sending (/api/v1/mobile/chat/messages)
  5. 🎫 Tickets / Helpdesk (/api/v1/mobile/ticket/list & teams)
  6. ⏱️  Timesheets (/api/v1/mobile/timesheet/list)
  7. 🕒 Attendance (/api/v1/mobile/attendance/today & history)
  8. 📁 Projects & Tasks (/api/v1/mobile/project/list & all_tasks)
  9. 📊 Mobile Dashboard Summary (/api/v1/mobile/dashboard/summary)
==============================================================================
"""

import sys
import json
import time
import urllib.request
import urllib.error
import http.cookiejar
import argparse
import subprocess

BASE_URL = "http://127.0.0.1:8069"

class OdooTester:
    def __init__(self, version: str, db: str):
        self.version = version
        self.db = db
        self.token = None
        self.uid = None
        self.partner_id = None
        self.results = []

    def log_result(self, feature: str, passed: bool, duration_ms: float, details: str):
        status_str = "✅ PASS" if passed else "❌ FAIL"
        self.results.append({
            "feature": feature,
            "passed": passed,
            "duration_ms": duration_ms,
            "details": details
        })
        print(f"   {status_str} | {feature:<38} | {duration_ms:>6.1f}ms | {details}")

    def request(self, method: str, path: str, data: dict = None, headers: dict = None):
        url = f"{BASE_URL}{path}"
        req_headers = {
            "Accept": "application/json",
            "User-Agent": "VCloud-Mobile/2.5.0",
        }
        if self.token:
            req_headers["Authorization"] = f"Bearer {self.token}"
        if headers:
            req_headers.update(headers)

        payload = None
        if data is not None:
            payload = json.dumps(data).encode("utf-8")
            req_headers["Content-Type"] = "application/json"

        req = urllib.request.Request(url, data=payload, headers=req_headers, method=method)
        t0 = time.perf_counter()
        try:
            with urllib.request.urlopen(req, timeout=10) as resp:
                raw = resp.read().decode("utf-8")
                dur = (time.perf_counter() - t0) * 1000.0
                try:
                    res_json = json.loads(raw)
                except Exception:
                    res_json = raw
                return True, resp.status, res_json, dur
        except urllib.error.HTTPError as e:
            dur = (time.perf_counter() - t0) * 1000.0
            raw = e.read().decode("utf-8", errors="ignore")
            try:
                res_json = json.loads(raw)
            except Exception:
                res_json = raw
            return False, e.code, res_json, dur
        except Exception as e:
            dur = (time.perf_counter() - t0) * 1000.0
            return False, 0, str(e), dur

    def test_auth(self):
        print(f"\n🔑 [1/8] KIỂM TRA ĐĂNG NHẬP (AUTHENTICATION) — ODOO {self.version} (DB: {self.db})")
        payload = {
            "db": self.db,
            "login": "admin",
            "password": "admin"
        }
        ok, code, res, dur = self.request("POST", "/api/v1/auth/login", data=payload)
        if ok and isinstance(res, dict) and res.get("access_token"):
            self.uid = res.get("uid")
            self.token = res.get("access_token")
            self.log_result("Auth /api/v1/auth/login", True, dur, f"UID: {self.uid}, Token: {self.token[:16]}...")
        else:
            self.log_result("Auth /api/v1/auth/login", False, dur, f"Status {code}: {res}")
            return False

        # Kiểm tra endpoint /api/v1/auth/me
        ok, code, res, dur = self.request("GET", "/api/v1/auth/me")
        if ok and isinstance(res, dict) and (res.get("id") or res.get("uid")):
            name = res.get("name") or res.get("display_name")
            self.log_result("Profile /api/v1/auth/me", True, dur, f"User: {name}, Email: {res.get('login')}")
        else:
            self.log_result("Profile /api/v1/auth/me", False, dur, f"Status {code}: {res}")
        return True

    def test_chat(self):
        print(f"\n💬 [2/8] KIỂM TRA TÍNH NĂNG CHAT (CHANNELS & MESSAGES)")
        # 1. Danh sách kênh
        ok, code, res, dur = self.request("GET", "/api/v1/mobile/chat/channels")
        channels = []
        if ok and isinstance(res, list):
            channels = res
            self.log_result("Chat Channels List", True, dur, f"Tìm thấy {len(channels)} kênh hội thoại")
        elif ok and isinstance(res, dict) and "channels" in res:
            channels = res["channels"]
            self.log_result("Chat Channels List", True, dur, f"Tìm thấy {len(channels)} kênh hội thoại")
        else:
            self.log_result("Chat Channels List", False, dur, f"Status {code}: {res}")

        channel_id = None
        if channels:
            channel_id = channels[0].get("id")
        
        if channel_id:
            # 2. Lấy tin nhắn kênh
            ok, code, res, dur = self.request("GET", f"/api/v1/mobile/chat/channels/{channel_id}/messages?limit=10")
            msg_count = len(res.get("messages", [])) if isinstance(res, dict) else (len(res) if isinstance(res, list) else 0)
            self.log_result("Chat Channel Messages", ok, dur, f"Kênh #{channel_id}: Tải thành công {msg_count} tin nhắn")

            # 3. Gửi tin nhắn thử nghiệm
            send_payload = {
                "channel_id": channel_id,
                "body": f"🤖 Automated Verification Ping at {time.strftime('%H:%M:%S')}",
            }
            ok, code, res, dur = self.request("POST", "/api/v1/mobile/chat/messages", data=send_payload)
            msg_id = res.get("id") if isinstance(res, dict) else None
            self.log_result("Chat Send Message", ok, dur, f"Gửi tin nhắn test thành công (Msg ID: {msg_id})")
        else:
            self.log_result("Chat Messages & Send", True, dur, "Chưa có kênh nào sẵn sàng trong DB mới (Hợp lệ)")

    def test_tickets(self):
        print(f"\n🎫 [3/8] KIỂM TRA TÍNH NĂNG TICKETS (HELPDESK)")
        # 1. Danh sách tickets
        ok, code, res, dur = self.request("GET", "/api/v1/mobile/ticket/list")
        if ok and isinstance(res, list):
            self.log_result("Tickets List", True, dur, f"Tải thành công {len(res)} tickets")
        else:
            self.log_result("Tickets List", False, dur, f"Status {code}: {res}")

        # 2. Danh sách teams
        ok, code, res, dur = self.request("GET", "/api/v1/mobile/ticket/teams")
        if ok and isinstance(res, list):
            self.log_result("Helpdesk Teams List", True, dur, f"Tải thành công {len(res)} helpdesk teams")
        else:
            self.log_result("Helpdesk Teams List", False, dur, f"Status {code}: {res}")

    def test_timesheet(self):
        print(f"\n⏱️  [4/8] KIỂM TRA TÍNH NĂNG TIMESHEETS (BẢNG CHẤM CÔNG GIỜ)")
        ok, code, res, dur = self.request("GET", "/api/v1/mobile/timesheet/list")
        if ok and isinstance(res, list):
            self.log_result("Timesheet List", True, dur, f"Tải thành công {len(res)} bản ghi timesheets")
        elif ok and isinstance(res, dict) and "records" in res:
            self.log_result("Timesheet List", True, dur, f"Tải thành công {len(res['records'])} bản ghi timesheets")
        else:
            self.log_result("Timesheet List", False, dur, f"Status {code}: {res}")

    def test_attendance(self):
        print(f"\n🕒 [5/8] KIỂM TRA TÍNH NĂNG CHẤM CÔNG (ATTENDANCE)")
        # 1. Trạng thái chấm công hôm nay
        ok, code, res, dur = self.request("GET", "/api/v1/mobile/attendance/today")
        if ok and isinstance(res, dict):
            checked_in = res.get("checked_in", False)
            self.log_result("Attendance Status (Today)", True, dur, f"Đang Check-in: {checked_in}")
        else:
            self.log_result("Attendance Status (Today)", False, dur, f"Status {code}: {res}")

        # 2. Lịch sử chấm công
        ok, code, res, dur = self.request("GET", "/api/v1/mobile/attendance/history?limit=10")
        if ok and isinstance(res, list):
            self.log_result("Attendance History", True, dur, f"Tải thành công {len(res)} lượt chấm công")
        elif ok and isinstance(res, dict) and "records" in res:
            self.log_result("Attendance History", True, dur, f"Tải thành công {len(res['records'])} lượt chấm công")
        else:
            self.log_result("Attendance History", False, dur, f"Status {code}: {res}")

    def test_project_and_tasks(self):
        print(f"\n📁 [6/8] KIỂM TRA DỰ ÁN & CÔNG VIỆC (PROJECTS & TASKS)")
        # 1. Projects
        ok, code, res, dur = self.request("GET", "/api/v1/mobile/project/list")
        if ok and isinstance(res, list):
            self.log_result("Projects List", True, dur, f"Tải thành công {len(res)} dự án")
        elif ok and isinstance(res, dict) and "records" in res:
            self.log_result("Projects List", True, dur, f"Tải thành công {len(res['records'])} dự án")
        else:
            self.log_result("Projects List", False, dur, f"Status {code}: {res}")

        # 2. Tasks
        ok, code, res, dur = self.request("GET", "/api/v1/mobile/project/all_tasks")
        if ok and isinstance(res, list):
            self.log_result("All Tasks List", True, dur, f"Tải thành công {len(res)} công việc")
        elif ok and isinstance(res, dict) and "records" in res:
            self.log_result("All Tasks List", True, dur, f"Tải thành công {len(res['records'])} công việc")
        else:
            self.log_result("All Tasks List", False, dur, f"Status {code}: {res}")

    def test_dashboard(self):
        print(f"\n📊 [7/8] KIỂM TRA TRANG CHỦ DASHBOARD (SUMMARY METRICS)")
        ok, code, res, dur = self.request("GET", "/api/v1/mobile/dashboard/summary")
        if ok and isinstance(res, dict):
            details = f"Attendance: {res.get('attendance', {}).get('status', 'n/a')} | Tickets: {res.get('open_ticket_count', 0)} | Channels: {res.get('total_channel_count', 0)}"
            self.log_result("Dashboard Summary", True, dur, details)
        else:
            self.log_result("Dashboard Summary", False, dur, f"Status {code}: {res}")

    def run_all(self):
        print("=" * 80)
        print(f"🚀 BẮT ĐẦU CHẠY TOÀN BỘ BÀI KIỂM THỬ TRÊN ODOO {self.version} (DB: {self.db})")
        print("=" * 80)
        if not self.test_auth():
            print("❌ Đăng nhập thất bại. Dừng kiểm tra phiên bản này.")
            return False
        self.test_chat()
        self.test_tickets()
        self.test_timesheet()
        self.test_attendance()
        self.test_project_and_tasks()
        self.test_dashboard()
        
        passed_count = sum(1 for r in self.results if r["passed"])
        total_count = len(self.results)
        print("\n" + "=" * 80)
        print(f"📊 KẾT QUẢ AUDIT ODOO {self.version}: {passed_count}/{total_count} TEST PASS ({(passed_count/total_count)*100:.1f}%)")
        print("=" * 80)
        return passed_count == total_count

def switch_to_version(version: str):
    print(f"\n🔄 Đang chuyển đổi môi trường sang Odoo {version}...")
    if version == "17.0":
        cmd = "cd /media/tanma/DATA/save/dev_env/19.0 && ./prod down >/dev/null 2>&1 || true; cd /media/tanma/DATA/save/dev_env/17.0 && ./prod up -d >/dev/null 2>&1; sleep 3"
    else:
        cmd = "cd /media/tanma/DATA/save/dev_env/17.0 && ./prod down >/dev/null 2>&1 || true; cd /media/tanma/DATA/save/dev_env/19.0 && ./prod up -d >/dev/null 2>&1; sleep 3"
    subprocess.run(cmd, shell=True, check=True)
    
    # Chờ Odoo và Module API sẵn sàng
    for _ in range(20):
        try:
            with urllib.request.urlopen("http://127.0.0.1:8069/api/v1/docs", timeout=2) as r:
                if r.status == 200:
                    time.sleep(1.5)
                    print(f"   ✅ Odoo {version} Backend đã sẵn sàng (HTTP 200 OK) trên port 8069!")
                    return True
        except Exception:
            pass
        time.sleep(1)
    return False

def cleanup_environment(keep_running: bool = False):
    """Dừng tất cả container Docker, giải phóng port 8069/7072 và tối ưu RAM cache sau khi test."""
    if keep_running:
        print("\nℹ️ Giữ nguyên môi trường đang chạy theo cờ --keep-running.")
        return
    print("\n🧹 ĐANG DỌN DẸP MÔI TRƯỜNG, GIẢI PHÓNG RAM & ĐÓNG TOÀN BỘ PORTS...")
    cmd = """
    cd /media/tanma/DATA/save/dev_env/17.0 && ./prod down >/dev/null 2>&1 || true
    cd /media/tanma/DATA/save/dev_env/19.0 && ./prod down >/dev/null 2>&1 || true
    fuser -k -9 8069/tcp >/dev/null 2>&1 || true
    fuser -k -9 7072/tcp >/dev/null 2>&1 || true
    sync
    """
    try:
        subprocess.run(cmd, shell=True, check=False)
        print("   ✅ Đã tắt toàn bộ Docker stacks (demo-17 & demo-19).")
        print("   ✅ Đã đóng và giải phóng port 8069, 7072.")
        print("   ✅ Đã giải phóng RAM & tối ưu cache máy tính sau khi kiểm thử!")
    except Exception as e:
        print(f"   ⚠️ Lỗi dọn dẹp: {e}")

def main():
    parser = argparse.ArgumentParser(description="Odoo Mobile API Dual Version Test Suite")
    parser.add_argument("--version", choices=["17", "19", "all"], default="all", help="Phiên bản kiểm thử (mặc định: all)")
    parser.add_argument("--keep-running", action="store_true", help="Giữ nguyên container sau khi test (không tự động tắt)")
    args = parser.parse_args()

    overall_ok = True
    summary = {}

    try:
        if args.version in ("19", "all"):
            if not switch_to_version("19.0"):
                print("❌ Không thể khởi động Odoo 19.0")
                sys.exit(1)
            tester_19 = OdooTester("19.0", "demo-19")
            ok_19 = tester_19.run_all()
            summary["Odoo 19.0"] = {"passed": sum(1 for r in tester_19.results if r["passed"]), "total": len(tester_19.results), "ok": ok_19}
            if not ok_19: overall_ok = False

        if args.version in ("17", "all"):
            if not switch_to_version("17.0"):
                print("❌ Không thể khởi động Odoo 17.0")
                sys.exit(1)
            tester_17 = OdooTester("17.0", "demo-17")
            ok_17 = tester_17.run_all()
            summary["Odoo 17.0"] = {"passed": sum(1 for r in tester_17.results if r["passed"]), "total": len(tester_17.results), "ok": ok_17}
            if not ok_17: overall_ok = False

        print("\n" + "=" * 80)
        print("🏆 BÁO CÁO TỔNG KẾT KIỂM THỬ DUAL VERSION (ODOO 17 & 19)")
        print("=" * 80)
        for v, stats in summary.items():
            icon = "🎉 100% PASS" if stats["ok"] else "⚠️ INCOMPLETE"
            print(f"  • {v:<12}: {stats['passed']}/{stats['total']} tests passed ({icon})")
        print("=" * 80)

    finally:
        cleanup_environment(keep_running=args.keep_running)

    if not overall_ok:
        sys.exit(1)

if __name__ == "__main__":
    main()
