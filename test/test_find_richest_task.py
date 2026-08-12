#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Unit test quét toàn bộ Odoo API để tìm Task có dữ liệu ĐẦY ĐỦ NHẤT:
- Tên Task
- Mô tả dài (Description)
- Số giờ dự kiến (Allocated Hours)
- Số giờ đã làm (Effective Hours)
- Số giờ còn lại (Remaining Hours)
- Stage Name
- Tên Khách hàng / Partner Name
- Lượt trao đổi (Chatter Messages)
"""

import unittest
import json
import urllib.request
import os

BASE_URL = os.environ.get("VCLOUD_ODOO_API_BASE_URL", "https://vuahethong.net")
LOGIN_USER = os.environ.get("ODOO_USER", "tanmnn@360.org.vn")
LOGIN_PASS = os.environ.get("ODOO_PASS", "@360.org.vn")

class TestFindRichestTaskAPI(unittest.TestCase):
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

    def test_find_richest_task_in_odoo(self):
        projects = self._get("/api/v1/mobile/project/list")
        best_task = None
        best_score = -1

        all_rich_tasks = []

        print(f"\nScanning {len(projects)} projects in Odoo database for richest tasks...")

        for p in projects:
            try:
                tasks = self._get(f"/api/v1/mobile/project/{p['id']}/tasks")
                for t in tasks:
                    tid = t["id"]
                    try:
                        detail = self._get(f"/api/v1/mobile/project/task/{tid}")
                        desc = detail.get("description") or ""
                        alloc = detail.get("allocated_hours") or 0.0
                        spent = detail.get("effective_hours") or 0.0
                        stage = detail.get("stage_name") or ""
                        partner = detail.get("partner_name") or ""
                        msgs = len(detail.get("messages", []))

                        # Calculate richness score
                        score = 0
                        if desc and desc != "False":
                            score += 10 + min(len(desc), 100)
                        if alloc > 0:
                            score += 20
                        if spent > 0:
                            score += 20
                        if stage:
                            score += 10
                        if partner:
                            score += 10
                        score += min(msgs, 5) * 2

                        if score > 0:
                            all_rich_tasks.append((score, detail))

                        if score > best_score:
                            best_score = score
                            best_task = detail
                    except Exception:
                        pass
            except Exception:
                pass

        all_rich_tasks.sort(key=lambda x: x[0], reverse=True)

        print("\n==========================================================================")
        print("🎯 TOP 3 TASK CÓ DỮ LIỆU ĐẦY ĐỦ VÀ PHONG PHÚ NHẤT TRÊN CSDL ODOO API:")
        print("==========================================================================")

        for idx, (sc, task) in enumerate(all_rich_tasks[:3], 1):
            print(f"\n--- TOP {idx} (Score: {sc}) ---")
            print(f"Task ID: {task['id']}")
            print(f"Tiêu đề Task: '{task['name']}'")
            print(f"Dự án: {task.get('project_name')}")
            print(f"Khách hàng: {task.get('partner_name')}")
            print(f"Người phụ trách: {task.get('user_name')}")
            print(f"Stage: {task.get('stage_name')}")
            print(f"Số giờ dự kiến (allocated_hours): {task.get('allocated_hours')} giờ")
            print(f"Số giờ đã làm (effective_hours): {task.get('effective_hours')} giờ")
            print(f"Số giờ còn lại (remaining_hours): {task.get('remaining_hours')} giờ")
            print(f"Mô tả gốc (raw HTML): {repr(task.get('description'))}")
            print(f"Số lượng tin nhắn Chatter: {len(task.get('messages', []))}")
            print("-" * 74)

        self.assertIsNotNone(best_task, "Phải tìm thấy ít nhất 1 task có dữ liệu")

if __name__ == "__main__":
    unittest.main(verbosity=2)
