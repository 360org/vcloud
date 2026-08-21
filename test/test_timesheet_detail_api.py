#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Unit test kiểm tra API Chi tiết Task của Timesheet và xuất ra nội dung mô tả đầy đủ.
"""

import unittest
import json
import urllib.request
import os
import re

BASE_URL = os.environ.get("VCLOUD_ODOO_API_BASE_URL", "https://vuahethong.net")
LOGIN_USER = os.environ.get("ODOO_USER", "tanmnn@360.org.vn")
LOGIN_PASS = os.environ.get("ODOO_PASS", "@360.org.vn")

def clean_html(text):
    if not text or text == "False" or text == "false":
        return "Chưa có mô tả."
    text = re.sub(r'<br\s*/?>', '\n', text)
    text = re.sub(r'</p>', '\n', text)
    text = re.sub(r'<[^>]+>', '', text)
    lines = [line.strip() for line in text.split('\n') if line.strip()]
    cleaned = '\n'.join(lines)
    return cleaned if cleaned else "Chưa có mô tả."

class TestTimesheetDetailAPI(unittest.TestCase):
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

    def test_verify_task_descriptions(self):
        target_ids = [11354, 11356, 12137, 14756]
        print("\n==========================================================================")
        print("🎯 NỘI DUNG MÔ TẢ ĐẦY ĐỦ TRẢ VỀ TỪ ODOO API CHO CÁC TASK TRONG TIMESHEET:")
        print("==========================================================================")
        
        for tid in target_ids:
            detail = self._get(f"/api/v1/mobile/project/task/{tid}")
            raw_desc = detail.get("description")
            cleaned_desc = clean_html(raw_desc)
            
            print(f"\n📌 TASK ID: {detail['id']}")
            print(f"   • Tiêu đề Task: '{detail['name']}'")
            print(f"   • Dự án (Project): {detail.get('project_name')}")
            print(f"   • Khách hàng (Partner): {detail.get('partner_name') or 'N/A'}")
            print(f"   • Trạng thái (Stage): {detail.get('stage_name')}")
            print(f"   • Mô tả gốc (HTML từ Odoo): {repr(raw_desc)}")
            print(f"   • Mô tả hiển thị trên giao diện App: \n'''\n{cleaned_desc}\n'''")
            print("-" * 74)
            self.assertIsNotNone(detail.get("name"))

if __name__ == "__main__":
    unittest.main(verbosity=2)
