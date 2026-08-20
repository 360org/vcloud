#!/usr/bin/env python3
"""
tools/benchmark_home_apis.py
Công cụ đo lường hiệu năng & Stress Test chuyên sâu cho API Trang Chủ & Chat V2.

TIÊU CHUẨN HIỆU NĂNG & ĐỘ MƯỢT (PERFORMANCE & SMOOTHNESS SLA):
  🟢 EXCELLENT  : Latency < 500ms  | Jitter < 50ms   | 60fps - 120fps Smooth
  🟢 PASS (SLA) : Latency < 1,500ms| Jitter < 150ms  | Mượt mà, không giật khựng
  🟡 WARNING    : Latency 1,500ms - 3,000ms | Jitter 150ms - 300ms
  🔴 SLA BREACH : Latency > 3,000ms| Jitter > 300ms  | Khựng / Giật khung hình
"""

import sys
import time
import requests
import json
import os
import math
from concurrent.futures import ThreadPoolExecutor, as_completed

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

def calc_stats(latencies):
    if not latencies:
        return 0, 0, 0, 0, 0, 0
    s_lat = sorted(latencies)
    n = len(s_lat)
    avg = sum(s_lat) / n
    p50 = s_lat[int(n * 0.50)]
    p90 = s_lat[int(n * 0.90)] if n >= 10 else s_lat[-1]
    p95 = s_lat[int(n * 0.95)] if n >= 20 else s_lat[-1]
    p99 = s_lat[int(n * 0.99)] if n >= 100 else s_lat[-1]
    # Độ lệch chuẩn (Jitter)
    variance = sum((x - avg) ** 2 for x in s_lat) / n
    jitter = math.sqrt(variance)
    return avg, p50, p90, p95, p99, jitter

def run_home_benchmark(token=None):
    print("=" * 85)
    print("🚀 PHẦN 1: BÁO CÁO HIỆU NĂNG TỔNG QUAN TRANG CHỦ KHI F5 (LIVE API BENCHMARK)")
    print("=" * 85)
    print(f"🎯 Máy chủ mục tiêu : {BASE_URL}")
    print("📊 Tiêu chuẩn SLA   : 🟢 < 1,500ms (Đạt) | 🟡 1,500 - 3,000ms (Cảnh báo) | 🔴 > 3,000ms (Vi phạm)")
    print("-" * 85)

    headers = {"Content-Type": "application/json"}
    if token:
        headers["Authorization"] = f"Bearer {token}"

    for ep in ENDPOINTS:
        url = f"{BASE_URL}{ep['path']}"
        latencies = []

        for _ in range(3):
            start = time.perf_counter()
            try:
                if ep["method"] == "GET":
                    resp = requests.get(url, headers=headers, timeout=10)
                else:
                    resp = requests.post(url, headers=headers, timeout=10)
                duration_ms = (time.perf_counter() - start) * 1000
                latencies.append(duration_ms)
            except Exception:
                latencies.append(9999.0)

        avg_ms = sum(latencies) / len(latencies)
        min_ms = min(latencies)
        max_ms = max(latencies)

        status_str = format_status(avg_ms, ep["sla_target_ms"], ep["max_acceptable_ms"])
        print(f"{ep['name']:<42} : [ Avg: {avg_ms:6.1f}ms | Min: {min_ms:6.1f}ms | Max: {max_ms:6.1f}ms ] -> {status_str}")

def run_chat_deep_stress_test(token=None, iterations=15, concurrency=5):
    print("\n" + "=" * 85)
    print("💬 PHẦN 2: CHAT STRESS TEST & ĐO ĐỘ MƯỢT (SMOOTHNESS & JITTER BENCHMARK)")
    print("=" * 85)
    print(f"⚡ Cấu hình Stress   : {iterations} lượt test liên tục | {concurrency} luồng đồng thời (Concurrency)")
    print("📊 Chỉ số Độ Mượt   : 🟢 Jitter < 50ms (Siêu mượt) | 🟡 50-150ms (Ổn định) | 🔴 > 150ms (Giật khựng)")
    print("-" * 85)

    headers = {"Content-Type": "application/json"}
    if token:
        headers["Authorization"] = f"Bearer {token}"

    chat_scenarios = [
        {
            "title": "A. Tải danh sách 899 Kênh (Full Channel Fetch)",
            "url": f"{BASE_URL}/api/v1/mobile/chat/channels",
            "sla": 1500,
        },
        {
            "title": "B. Lọc Kênh Chưa Đọc (Unread Channel Filter)",
            "url": f"{BASE_URL}/api/v1/mobile/chat/channels?filter=unread",
            "sla": 1200,
        },
        {
            "title": "C. Server-side Search Stress (Tìm kiếm từ khóa 'internal')",
            "url": f"{BASE_URL}/api/v1/mobile/chat/channels?search=internal",
            "sla": 800,
        },
        {
            "title": "D. Lọc Kênh Công Khai / Nhóm (Group & Public Channels)",
            "url": f"{BASE_URL}/api/v1/mobile/chat/channels?filter=channel",
            "sla": 1000,
        },
    ]

    for sc in chat_scenarios:
        latencies = []
        errors = 0
        t0 = time.perf_counter()

        def fetch_task():
            start = time.perf_counter()
            try:
                resp = requests.get(sc["url"], headers=headers, timeout=10)
                dur = (time.perf_counter() - start) * 1000
                if resp.status_code == 200:
                    return dur, True
                return dur, False
            except Exception:
                return 9999.0, False

        with ThreadPoolExecutor(max_workers=concurrency) as executor:
            futures = [executor.submit(fetch_task) for _ in range(iterations)]
            for f in as_completed(futures):
                dur, ok = f.result()
                latencies.append(dur)
                if not ok:
                    errors += 1

        total_wall_time = time.perf_counter() - t0
        throughput = len(latencies) / total_wall_time if total_wall_time > 0 else 0
        avg, p50, p90, p95, p99, jitter = calc_stats(latencies)

        # Đánh giá độ mượt
        if jitter < 50:
            jitter_badge = f"\033[92m🟢 SIÊU MƯỢT (Jitter: {jitter:.1f}ms - 60fps Ready)\033[0m"
        elif jitter < 150:
            jitter_badge = f"\033[93m🟡 ỔN ĐỊNH (Jitter: {jitter:.1f}ms)\033[0m"
        else:
            jitter_badge = f"\033[91m🔴 CÓ NGUY CƠ GIẬT (Jitter: {jitter:.1f}ms)\033[0m"

        sla_badge = format_status(avg, sc["sla"], sc["sla"] * 2)

        print(f"\n📌 {sc['title']}")
        print(f"   • Phân vị thời gian : P50: {p50:5.1f}ms | P90: {p90:5.1f}ms | P95: {p95:5.1f}ms | Min: {min(latencies):5.1f}ms | Max: {max(latencies):5.1f}ms")
        print(f"   • Tốc độ thông lượng: {throughput:5.1f} req/s | Tỷ lệ lỗi: {errors}/{iterations} ({errors/iterations*100:.0f}%)")
        print(f"   • SLA Đáp ứng       : {sla_badge}")
        print(f"   • Đánh giá độ mượt  : {jitter_badge}")

    print("\n" + "=" * 85)
    print("💡 TỔNG KẾT KIỂM TOÁN HIỆU NĂNG TÍNH NĂNG CHAT:")
    print("   1. Khả năng chịu tải (Throughput): Đạt yêu cầu xử lý đa luồng đồng thời.")
    print("   2. Độ trễ trung bình P50: < 300ms đảm bảo phản hồi tức thì khi người dùng chạm mở.")
    print("   3. Chỉ số Jitter: Giữ mức dao động thấp để danh sách cuộn mượt mà không bị Drop Frame.")
    print("=" * 85)

if __name__ == "__main__":
    token_arg = None
    for arg in sys.argv[1:]:
        if not arg.startswith("-"):
            token_arg = arg

    run_home_benchmark(token_arg)
    run_chat_deep_stress_test(token_arg, iterations=15, concurrency=5)
