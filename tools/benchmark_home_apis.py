#!/usr/bin/env python3
"""
tools/benchmark_home_apis.py
Công cụ đo lường hiệu năng thời gian thực các API Trang Chủ (Home F5 Latency Benchmark).

Định nghĩa Tiêu chuẩn Hiệu năng (Performance SLA Targets):
  🟢 EXCELLENT  : < 500ms
  🟢 PASS (SLA) : < 1,500ms
  🟡 WARNING    : 1,500ms - 3,000ms
  🔴 SLA BREACH : > 3,000ms (Cần tối ưu indexing / caching)
"""

import sys
import time
import requests
import json

import os

BASE_URL = os.environ.get("ODOO_URL", "https://vuahethong.net")

ENDPOINTS = [
    {
        "name": "1. ⏱️  CHẤM CÔNG (Today Status)",
        "path": "/api/v1/mobile/attendance/today",
        "method": "GET",
        "sla_target_ms": 1000,
        "max_acceptable_ms": 2000,
    },
    {
        "name": "2. ⏱️  CẤU HÌNH CA LÀM VIỆC (Shift Config)",
        "path": "/api/v1/mobile/attendance/config",
        "method": "GET",
        "sla_target_ms": 800,
        "max_acceptable_ms": 1500,
    },
    {
        "name": "3. 🎫 TICKETS (Helpdesk Summary)",
        "path": "/api/v1/mobile/helpdesk/tickets?limit=20",
        "method": "GET",
        "sla_target_ms": 1000,
        "max_acceptable_ms": 2000,
    },
    {
        "name": "4. 📋 CÔNG VIỆC HÔM NAY (Project Tasks)",
        "path": "/api/v1/mobile/project/tasks?limit=50",
        "method": "GET",
        "sla_target_ms": 1200,
        "max_acceptable_ms": 2500,
    },
    {
        "name": "5. 💬 CHATS (Tổng 899 kênh trò chuyện)",
        "path": "/api/v1/mobile/chat/channels",
        "method": "GET",
        "sla_target_ms": 1500,
        "max_acceptable_ms": 3000,
    },
    {
        "name": "6. 📬 CHƯA ĐỌC (Lọc kênh có tin nhắn mới)",
        "path": "/api/v1/mobile/chat/channels?filter=unread",
        "method": "GET",
        "sla_target_ms": 1200,
        "max_acceptable_ms": 2500,
    },
    {
        "name": "7. 📊 DASHBOARD (Tổng quan 4 widget)",
        "path": "/api/v1/mobile/dashboard/summary",
        "method": "GET",
        "sla_target_ms": 800,
        "max_acceptable_ms": 1500,
    },
]

def format_status(latency_ms, sla_target, max_acceptable):
    if latency_ms <= sla_target:
        return f"\033[92m[ EXCELLENT: {latency_ms:.0f}ms <= {sla_target}ms ]\033[0m"
    elif latency_ms <= max_acceptable:
        return f"\033[93m[ ACCEPTABLE: {latency_ms:.0f}ms <= {max_acceptable}ms ]\033[0m"
    else:
        return f"\033[91m[ ❌ SLA BREACH: {latency_ms:.0f}ms > {max_acceptable}ms ]\033[0m"

def run_benchmark(token=None):
    print("=" * 80)
    print("🚀 BÁO CÁO KIỂM THỬ HIỆU NĂNG LOAD DATA TRANG CHỦ KHI F5 (LIVE API BENCHMARK)")
    print("=" * 80)
    print(f"🎯 Máy chủ mục tiêu : {BASE_URL}")
    print("📊 Tiêu chuẩn SLA   : 🟢 < 1,500ms (Đạt) | 🟡 1,500 - 3,000ms (Cảnh báo) | 🔴 > 3,000ms (Vi phạm)")
    print("-" * 80)

    headers = {"Content-Type": "application/json"}
    if token:
        headers["Authorization"] = f"Bearer {token}"

    results = []

    for ep in ENDPOINTS:
        url = f"{BASE_URL}{ep['path']}"
        latencies = []

        # Chạy 3 lần đo để lấy trung bình (P50)
        for _ in range(3):
            start = time.perf_counter()
            try:
                if ep["method"] == "GET":
                    resp = requests.get(url, headers=headers, timeout=10)
                else:
                    resp = requests.post(url, headers=headers, timeout=10)
                duration_ms = (time.perf_counter() - start) * 1000
                latencies.append(duration_ms)
            except Exception as e:
                latencies.append(9999.0)

        avg_ms = sum(latencies) / len(latencies)
        min_ms = min(latencies)
        max_ms = max(latencies)

        status_str = format_status(avg_ms, ep["sla_target_ms"], ep["max_acceptable_ms"])
        print(f"{ep['name']:<42} : [ Avg: {avg_ms:6.1f}ms | Min: {min_ms:6.1f}ms | Max: {max_ms:6.1f}ms ] -> {status_str}")
        results.append({"name": ep["name"], "avg_ms": avg_ms, "status": status_str})

    print("-" * 80)
    print("💡 HƯỚNG DẪN ĐÁNH GIÁ:")
    print("   • Các API dưới 1,500ms: Đạt tiêu chuẩn trải nghiệm di động mượt mà.")
    print("   • Các API từ 1,500ms đến 3,000ms: Cần kích hoạt Local Cache để người dùng không phải chờ đợi.")
    print("   • Các API trên 3,000ms: Cần bổ sung phân trang (Pagination/Lazy Loading) hoặc Server Indexing.")
    print("=" * 80)

if __name__ == "__main__":
    token_arg = sys.argv[1] if len(sys.argv) > 1 else None
    run_benchmark(token_arg)
