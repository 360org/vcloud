#!/usr/bin/env python3
"""
VCloud Enterprise Mobile App - 1,000 Iteration Load Test Suite
Executes continuous performance and stability testing for Chat Features.
"""

import sys
import time
import argparse
import subprocess

def run_load_test_loop(target_iterations: int = 1000, batch_size: int = 10):
    print("=================================================================")
    print(f"🚀 VCLOUD ENTERPRISE LOAD TEST: {target_iterations} CONTINUOUS ITERATIONS")
    print("=================================================================")
    
    test_command = [
        "/home/tanma/flutter/bin/flutter",
        "test",
        "test/chat_features_integration_test.dart"
    ]
    
    total_passed = 0
    total_failed = 0
    durations = []
    
    start_time = time.time()
    
    print(f"[*] Starting execution of {target_iterations} iterations...")
    
    # Run test suite loops
    for i in range(1, target_iterations + 1):
        iter_start = time.time()
        try:
            res = subprocess.run(
                test_command,
                cwd="/media/tanma/DATA/save/mobile/vclients",
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                text=True,
                timeout=30
            )
            elapsed = time.time() - iter_start
            durations.append(elapsed)
            
            if res.returncode == 0:
                total_passed += 1
            else:
                total_failed += 1
                print(f"[!] Iteration #{i} FAILED: {res.stderr[:200]}")
                
        except Exception as e:
            elapsed = time.time() - iter_start
            durations.append(elapsed)
            total_failed += 1
            print(f"[!] Iteration #{i} Exception: {e}")
            
        if i % batch_size == 0 or i == target_iterations:
            avg_lat = sum(durations) / len(durations) if durations else 0
            pass_rate = (total_passed / i) * 100
            print(f"➜ Progress: [{i}/{target_iterations}] | Pass Rate: {pass_rate:.1f}% | Avg Latency: {avg_lat*1000:.1f}ms")
            
    total_duration = time.time() - start_time
    avg_latency = (sum(durations) / len(durations)) * 1000 if durations else 0
    min_latency = min(durations) * 1000 if durations else 0
    max_latency = max(durations) * 1000 if durations else 0
    
    print("\n=================================================================")
    print("📊 FINAL LOAD TEST STABILITY REPORT (1,000 ITERATIONS)")
    print("=================================================================")
    print(f"• Total Iterations Executed  : {target_iterations}")
    print(f"• Successful Pass Count     : {total_passed} ✅")
    print(f"• Failures / Timeouts        : {total_failed} ❌")
    print(f"• Final Pass Rate            : {(total_passed / target_iterations) * 100:.2f}%")
    print(f"• Total Execution Time       : {total_duration:.2f}s")
    print(f"• Min Latency                : {min_latency:.1f}ms")
    print(f"• Max Latency                : {max_latency:.1f}ms")
    print(f"• Average Rendering Latency  : {avg_latency:.1f}ms")
    print("=================================================================")
    
    return total_failed == 0

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Run continuous Flutter integration load tests.")
    parser.add_argument("--iterations", type=int, default=100, help="Number of continuous iterations to run.")
    args = parser.parse_args()
    
    success = run_load_test_loop(target_iterations=args.iterations)
    sys.exit(0 if success else 1)
