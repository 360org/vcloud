#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Unit test kiểm tra chính xác các trường Thời gian (Hours) từ Odoo API.
"""

import unittest
import json
import urllib.request
import os

BASE_URL = os.environ.get("VCLOUD_ODOO_API_BASE_URL", "https://vuahethong.net")
LOGIN_USER = os.environ.get("ODOO_USER", "tanmnn@360.org.vn")
LOGIN_PASS = os.environ.get("ODOO_PASS", "@360.org.vn")

class TestTaskHoursAPI(unittest.TestCase):
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
            res_dict = data.get("result", data)
            cls.token = res_dict.get("access_token")

    def _get(self, endpoint):
        url = f"{BASE_URL}{endpoint}"
        req = urllib.request.Request(
            url,
            headers={"Authorization": f"Bearer {self.token}", "User-Agent": "Mozilla/5.0"},
        )
        with urllib.request.urlopen(req) as res:
            return json.loads(res.read().decode("utf-8"))

    def test_verify_task_prd248_hours(self):
        # Task ID 11998 is '[PRD248] News Page'
        detail = self._get("/api/v1/mobile/project/task/11998")
        
        print("\n==========================================================================")
        print("🎯 KẾT QUẢ API TRẢ VỀ DỮ LIỆU THỜI GIAN CHO TASK '[PRD248] News Page' (ID: 11998):")
        print("==========================================================================")
        print(f"Task ID: {detail['id']}")
        print(f"Tiêu đề: '{detail['name']}'")
        print(f"Dự án: {detail.get('project_name')}")
        print(f"Trạng thái (state): {detail.get('state')} | Stage: {detail.get('stage_name')}")
        print(f"Hoàn thành lúc (date_end): {detail.get('date_end')}")
        print(f"1. Thời gian dự kiến (allocated_hours): {repr(detail.get('allocated_hours'))}")
        print(f"2. Tổng thời gian đã làm (effective_hours): {repr(detail.get('effective_hours'))}")
        print(f"3. Thời gian còn lại (remaining_hours): {repr(detail.get('remaining_hours'))}")
        print("==========================================================================")
        
        self.assertEqual(detail["id"], 11998)
        self.assertIsNone(detail.get("allocated_hours"), "Thời gian dự kiến trên CSDL Odoo hiện tại đang là None")
        self.assertIsNone(detail.get("effective_hours"), "Tổng thời gian đã làm trên CSDL Odoo hiện tại đang là None")

if __name__ == "__main__":
    unittest.main(verbosity=2)
