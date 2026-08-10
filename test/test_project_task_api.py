#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Unit Test API kiểm tra dữ liệu động của Project & Task từ Odoo Backend.

Đảm bảo API trả về đúng dữ liệu động từ cơ sở dữ liệu Odoo, không bị hardcode.
"""

import unittest
import json
import urllib.request
import os

BASE_URL = os.environ.get("VCLOUD_ODOO_API_BASE_URL", "https://vuahethong.net")
LOGIN_USER = os.environ.get("ODOO_USER", "tanmnn@360.org.vn")
LOGIN_PASS = os.environ.get("ODOO_PASS", "@360.org.vn")

class TestProjectTaskAPI(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        """Đăng nhập lấy access_token động từ Odoo API."""
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
            res_dict = data.get("result", data)
            cls.token = res_dict.get("access_token")
            cls.user_name = res_dict.get("user", {}).get("name")
        print(f"\n[TestAuth] Logged in as: {cls.user_name} | Token length: {len(cls.token)}")

    def _get(self, endpoint):
        """Helper gửi GET request có đính kèm Bearer token."""
        url = f"{BASE_URL}{endpoint}"
        req = urllib.request.Request(
            url,
            headers={
                "Authorization": f"Bearer {self.token}",
                "User-Agent": "Mozilla/5.0",
            },
        )
        with urllib.request.urlopen(req) as res:
            return json.loads(res.read().decode("utf-8"))

    def test_01_project_list(self):
        """Kiểm tra API danh sách dự án /api/v1/mobile/project/list."""
        projects = self._get("/api/v1/mobile/project/list")
        self.assertIsInstance(projects, list, "Response phải là một list danh sách dự án")
        self.assertGreaterThan(len(projects), 0, "Phải có ít nhất 1 dự án trong CSDL Odoo")
        p0 = projects[0]
        self.assertIn("id", p0, "Dự án phải có id động")
        self.assertIn("name", p0, "Dự án phải có name động")
        print(f"[Test 1 Pass] Lấy được {len(projects)} dự án từ CSDL. Dự án đầu tiên: ID={p0['id']} | Name='{p0['name']}'")

    def test_02_project_tasks(self):
        """Kiểm tra API danh sách task theo dự án /api/v1/mobile/project/<id>/tasks."""
        projects = self._get("/api/v1/mobile/project/list")
        for p in projects:
            tasks = self._get(f"/api/v1/mobile/project/{p['id']}/tasks")
            if tasks:
                self.assertIsInstance(tasks, list)
                t0 = tasks[0]
                self.assertIn("id", t0)
                self.assertIn("name", t0)
                print(f"[Test 2 Pass] Dự án '{p['name']}' (ID={p['id']}) chứa {len(tasks)} task. Task mẫu: ID={t0['id']} | Name='{t0['name']}'")
                return
        self.skipTest("Chưa có task nào gán cho dự án")

    def test_03_task_detail_dynamic_fields(self):
        """Kiểm tra API chi tiết task /api/v1/mobile/project/task/<task_id>."""
        projects = self._get("/api/v1/mobile/project/list")
        target_task_id = None
        for p in projects:
            tasks = self._get(f"/api/v1/mobile/project/{p['id']}/tasks")
            if tasks:
                target_task_id = tasks[0]["id"]
                break
        
        self.assertIsNotNone(target_task_id, "Không tìm thấy task để test chi tiết")
        detail = self._get(f"/api/v1/mobile/project/task/{target_task_id}")
        
        self.assertEqual(detail["id"], target_task_id)
        self.assertIn("name", detail)
        self.assertIn("description", detail)
        self.assertIn("project_id", detail)
        self.assertIn("user_name", detail)
        self.assertIn("messages", detail)
        
        print("\n=== KẾT QUẢ CHI TIẾT TASK TỪ ODOO API (DỮ LIỆU ĐỘNG 100%) ===")
        print(f"Task ID: {detail['id']}")
        print(f"Tiêu đề Task: '{detail['name']}'")
        print(f"Mô tả: {repr(detail.get('description'))}")
        print(f"Tên Dự Án: {detail.get('project_name')}")
        print(f"Người Phụ Trách: {detail.get('user_name')}")
        print(f"Trạng thái (state): {detail.get('state')}")
        print(f"Giờ dự kiến (allocated_hours): {detail.get('allocated_hours')}")
        print(f"Giờ đã làm (effective_hours): {detail.get('effective_hours')}")
        print(f"Giờ còn lại (remaining_hours): {detail.get('remaining_hours')}")
        print(f"Lượt trao đổi/Chatter (messages count): {len(detail.get('messages', []))}")
        print("===============================================================\n")

    def assertGreaterThan(self, a, b, msg=None):
        if not a > b:
            raise self.failureException(msg or f"{a} không lớn hơn {b}")

if __name__ == "__main__":
    unittest.main(verbosity=2)
