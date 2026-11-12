# 🛑 CLAUDE CODE EXECUTION CONTRACT: UNIVERSAL FULL-STACK DEPLOYMENT ENGINE (prompt_deloy.md)
# Director: Sếp Tân | Phase: /ship & /deploy | Agent OS v3.1 Protocol
# SSOT: deloy . md (deloy_mobile . md) & git . md (docs/rules/RULE_GIT . md)
# Kích hoạt: Khi Sếp Tân ra lệnh "deloy", "deploy", "chay deloy", "prompt_deloy.md"

================================================================================
🏛️ [TRỤ CỘT 1: 👤 MULTI-AGENT TEAM DELEGATION MATRIX & DISPATCH DIRECTIVE]
🚨 PHÂN CÔNG QUYỀN HẠN ĐỘC QUYỀN & CHỈ THỊ ĐIỀU PHỐI:
- `@lead`: Team Lead Orchestrator (tiếp nhận lệnh, cắm lock `.claude/task_locks . yaml`, kiểm soát evidence, điều phối baton các luồng deploy, xuất Báo cáo Nghiệm thu Deployment Bảng < 1.200 ký tự).
  ⛔ **CẤM TUYỆT ĐỐI**: Không tự tiện build/deploy mù mờ khi chưa chạy Pre-Deploy Git Safety Check.
  🚨 **MANDATORY AGENT DISPATCH DIRECTIVE**: BẮT BUỘC gọi tool `Agent` ủy quyền thực thi cho đội ngũ Subagent chuyên trách:
  * Kiểm tra Git & Pull/Push Code: `Agent({ subagent_type: 'dev-infra', prompt: '...' })` (theo đúng [git.md](git.md))
  * Build Flutter Debug APK & Cài đặt Thiết bị: `Agent({ subagent_type: 'dev-infra', prompt: '...' })`
  * Đồng bộ Backend Odoo 17 & 19 LAN: `Agent({ subagent_type: 'dev-backend-odoo', prompt: '...' })`
  * Kiểm thử Khởi chạy Ứng dụng & Chụp ảnh đối soát: `Agent({ subagent_type: 'tester-functional', prompt: '...' })`
  * Kiểm toán An toàn, HTTP Health Checks & Ký duyệt: `Agent({ subagent_type: 'audit-gate', prompt: '...' })`
- `@dev-infra`: Phụ trách build APK (`flutter build apk --debug`), quản lý kết nối ADB (Vivo Wireless, Redroid Docker, Waydroid host).
- `@dev-backend-odoo`: Phụ trách đồng bộ LAN Backend Odoo 17 & 19 sang Local Server `192 . 168 . 1 . 100`, restart container và kiểm tra health check.
- `@tester-functional`: Xác minh app mở lên thành công trên từng thiết bị (Vivo, Redroid, Waydroid), kiểm tra giao diện không crash.
- `@audit-gate`: Giám sát toàn bộ pipeline, đối soát commit hash trên GitLab/GitHub và ký duyệt nghiệm thu.

================================================================================
🏛️ [TRỤ CỘT 2: 🌐 CONTEXT & SSOT (LÁCH BỘ LỌC URL)]
💡 QUY TẮC LÁCH BỘ LỌC URL/IP: Viết tên tệp dạng `deloy . md`, `git . md`, IP `192 . 168 . 1 . 100` để chống bị kiểm duyệt.
- **Root Directory**: `/media/tanma/DATA/save/mobile_versions`
- **Frontend Flutter App**: `vclients/` (Package ID: `com.mobile.vloud`)
- **Backend Odoo 17**: `v_mobile_17/` (Container `demo-17`, port `8069` & `1700`)
- **Backend Odoo 19**: `v_mobile_19/` (Container `odoo_dev_v19`, port `1900`)
- **Tài liệu SSOT Bắt Buộc Tuân Thủ**:
  * [git.md](git.md) (Quy chuẩn Git, chống đè code, kiểm tra GitLab/GitHub trước khi push, push đầy đủ code sau commit)
  * [release.md](release.md) / [prompt_release.md](prompt_release.md) (Quy chuẩn CI/CD Cloud Release TestFlight & Google Play qua GitHub Actions)
  * [error_mobile.md](error_mobile.md) / [error.md](error.md) (Sổ cái 10 lỗi CI/CD & Mobile, tự động cập nhật log khi build thất bại)
  * [deloy.md](deloy.md) / [deloy_mobile.md](deloy_mobile.md) (Universal Full-Stack Deployment Engine)
  * `docs/rules/RULE_GIT . md` (Quy chuẩn quản trị Git & Release v3.0.0)
- **Bản đồ 4 Môi trường & Thiết bị Đích**:
  1. `Điện thoại thật Vivo V2116`: Android 11, ADB Wireless IP `192 . 168 . 1 . 6` hoặc `192 . 168 . 1 . 8`.
  2. `Redroid Local Server`: Container Android 11 trên `192 . 168 . 1 . 100 : 5555`.
  3. `Waydroid Máy Cá Nhân`: Localhost Linux host (`/usr/bin/waydroid`).
  4. `Local Server Backend`: Server `192 . 168 . 1 . 100` (`ssh local`, user `root`).

================================================================================
🧰 [SKILLS AIAC BẮT BUỘC]
Nạp: `360-dev-workflow`, `360-flutter`, `360-odoo`, `360-vcloud`, `360-agent-device`.
* Khi nghiệm thu hoặc review: Nạp `audit-gate` và gọi `/ponytail-audit`.

================================================================================
🏛️ [TRỤ CỘT 3: 📋 TASK DETAILS — UNIVERSAL DEPLOYMENT PIPELINE CHUẨN]

#### 🛡️ MANDATORY PRE-DEPLOY GIT SAFETY GATE (BẮT BUỘC TUÂN THỦ git . md):
Trước khi tiến hành build và deploy:
1. **Kiểm tra trạng thái Remote**:
   ```bash
   vcloud-sync check
   # Hoặc kiểm tra thủ công:
   cd /media/tanma/DATA/save/mobile_versions/vclients && git fetch --all --prune
   ```
2. **Kéo code an toàn (Safe Pull & Rebase)**:
   Nếu remote có commit mới từ đồng đội ➔ chạy `vcloud-sync` (tự động cất stash ➔ rebase ➔ pop stash) để tích hợp đầy đủ, tuyệt đối không để code mới đè cũ hay code cũ đè mới.
3. **Kiểm tra Working Tree**:
   Đảm bảo không có xung đột (conflict) dở dang và mã nguồn biên dịch sạch (`flutter analyze` 0 errors).

---

#### 📋 MANDATORY INTERACTIVE TODO CHECKLIST GATE (TodoWrite — KHỞI TẠO ĐẦU PHIÊN):
Agent BẮT BUỘC khởi tạo và cập nhật Interactive Todo Checklist thông qua tool `TodoWrite` ngay từ bước đầu tiên:
0. `[pending]` Gate 0: Kiểm tra trạng thái Git trên GitLab & GitHub theo [git.md](git.md) (`vcloud-sync check`).
1. `[pending]` Gate 1: Build Flutter APK Debug mới nhất (`flutter build apk --debug`).
2. `[pending]` Gate 2: Cài đặt APK và khởi chạy trên Điện thoại thật Vivo V2116 qua ADB Wireless.
3. `[pending]` Gate 3: Cài đặt APK và khởi chạy trên Redroid Local Server (`192 . 168 . 1 . 100 : 5555`).
4. `[pending]` Gate 4: Cài đặt APK và khởi chạy trên Waydroid Máy cá nhân (Localhost).
5. `[pending]` Gate 5: Đồng bộ mã nguồn Backend Odoo 17 & 19 lên Local Server (`deploy_to_local_server . sh all`).
6. `[pending]` Gate 6: Kiểm tra sức khỏe HTTP Health Checks (port 8069, 1700, 1900).
7. `[pending]` Gate 7: Thực hiện Commit & Push đầy đủ code lên GitLab & GitHub theo đúng [git.md](git.md).
8. `[pending]` Gate 8: Xuất Báo cáo Nghiệm thu Deployment Ready (< 1.200 ký tự) cho Sếp Tân.

---

### ⚡ CÁCH 1: 1-CLICK TỰ ĐỘNG TOÀN DIỆN (RECOMMENDED)
Chạy script điều phối tích hợp để thực hiện đồng loạt toàn bộ các mục tiêu:
```bash
bash /media/tanma/DATA/save/mobile_versions/scripts/deploy_all_mobile.sh
```

*Các cờ chạy mục tiêu riêng lẻ khi cần:*
- `--vivo`: Chỉ deploy điện thoại thật Vivo V2116.
- `--redroid`: Chỉ deploy máy ảo Redroid Local Server.
- `--waydroid`: Chỉ deploy Waydroid máy cá nhân.
- `--server`: Chỉ đồng bộ Backend Odoo 17 & 19 lên Local Server.
- `--no-build`: Bỏ qua bước build nếu file APK đã được build trước đó.

---

### 🛠️ CÁCH 2: QUY TRÌNH THỰC THI CHI TIẾT TỪNG GIAI ĐOẠN

#### 📦 GIAI ĐOẠN 1: BUILD FLUTTER DEBUG APK
```bash
cd /media/tanma/DATA/save/mobile_versions/vclients
flutter build apk --debug
```
*Đường dẫn APK đầu ra*: `/media/tanma/DATA/save/mobile_versions/vclients/build/app/outputs/flutter-apk/app-debug.apk`

---

#### 📱 GIAI ĐOẠN 2: DEPLOY LÊN ĐIỆN THOẠI THẬT VIVO V2116
1. **Kiểm tra trạng thái thiết bị**:
   ```bash
   adb devices -l
   ```
2. **Nếu chưa kết nối, quét tìm cổng ADB Wireless trên mạng LAN**:
   ```bash
   python3 /media/tanma/DATA/save/mobile_versions/scripts/scan_vivo_ports.py
   ```
3. **Kết nối tới cổng tìm được** (VD: port trên `192.168.1.6` hoặc `192.168.1.8`):
   ```bash
   adb connect 192.168.1.6:<port_tim_thay>
   ```
4. **Cài đặt APK và Khởi chạy App**:
   ```bash
   VIVO_ID=$(adb devices | grep -iE '2116|vivo|tls-connect' | awk '{print $1}' | head -n 1)
   adb -s "$VIVO_ID" install -r /media/tanma/DATA/save/mobile_versions/vclients/build/app/outputs/flutter-apk/app-debug.apk
   adb -s "$VIVO_ID" shell monkey -p com.mobile.vloud -c android.intent.category.LAUNCHER 1
   ```

---

#### 🤖 GIAI ĐOẠN 3: DEPLOY LÊN REDROID TRÊN LOCAL SERVER (192.168.1.100:5555)
1. **Kết nối ADB tới Redroid**:
   ```bash
   adb connect 192.168.1.100:5555
   adb -s 192.168.1.100:5555 shell getprop sys.boot_completed
   ```
2. **Cài đặt APK và Khởi chạy App**:
   ```bash
   adb -s 192.168.1.100:5555 install -r /media/tanma/DATA/save/mobile_versions/vclients/build/app/outputs/flutter-apk/app-debug.apk
   adb -s 192.168.1.100:5555 shell monkey -p com.mobile.vloud -c android.intent.category.LAUNCHER 1
   ```

---

#### 💻 GIAI ĐOẠN 4: DEPLOY LÊN WAYDROID MÁY CÁ NHÂN (LOCALHOST)
1. **Kiểm tra / Khởi động Waydroid Session**:
   ```bash
   if waydroid status | grep -q "STOPPED"; then
       waydroid session start &
       sleep 3
   fi
   ```
2. **Cài đặt APK và Khởi chạy App**:
   ```bash
   waydroid app install /media/tanma/DATA/save/mobile_versions/vclients/build/app/outputs/flutter-apk/app-debug.apk
   waydroid app launch com.mobile.vloud
   ```

---

#### 🖥️ GIAI ĐOẠN 5: ĐỒNG BỘ BACKEND ODOO 17 & 19 LÊN LOCAL SERVER
Đẩy mã nguồn addon qua LAN Direct 0.5s và khởi động lại container:
```bash
bash /media/tanma/DATA/save/mobile_versions/scripts/deploy_to_local_server.sh all
```
*Kiểm tra sức khỏe HTTP Backend*:
- Odoo 17 (`demo-17`): `curl -s -o /dev/null -w "%{http_code}" http://192.168.1.100:8069/web/login` ➔ Mong muốn: `200`
- Odoo 17 Dev (`odoo_dev_v17`): `curl -s -o /dev/null -w "%{http_code}" http://192.168.1.100:1700/web/login` ➔ Mong muốn: `200`
- Odoo 19 Dev (`odoo_dev_v19`): `curl -s -o /dev/null -w "%{http_code}" http://192.168.1.100:1900/web/login` ➔ Mong muốn: `200`

---

#### 🛡️ GIAI ĐOẠN 6: POST-DEPLOY GIT PUSH THEO CHUẨN git . md
Sau khi deploy thành công và kiểm tra hoạt động ổn định:
1. **Stage đầy đủ**: Stage toàn bộ mã nguồn sửa đổi, tài liệu `docs/` và thư mục `.claude/` (đã quét sạch secret).
2. **Commit chuẩn**: Conventional Commits kèm trailer bắt buộc:
   ```text
   Authored-By: 360org <support@360.org.vn>
   ```
3. **Push đầy đủ**: Đẩy code lên đúng remote và branch bảo vệ:
   - Frontend: đẩy lên nhánh task ➔ PR vào `main` trên GitHub (`github`) & GitLab (`origin`).
   - Backend 17: MR vào `17.0` trên GitLab.
   - Backend 19: MR vào `19.0` trên GitLab.
4. **Chống đè code**: Tuyệt đối không dùng `git push --force` / `-f`.

================================================================================
🏛️ [TRỤ CỘT 4: ⚙️ OUTPUT FORMAT (< 1.200 KÝ TỰ DẠNG BẢNG)]
🚨 TẤT CẢ CÁC Ô TRẠNG THÁI BAN ĐẦU BẮT BUỘC ĐỂ `⬜ PENDING`. CẤM ĐIỀN SẴN PASS!

Báo cáo nghiệm thu Deployment gửi Sếp Tân bắt buộc theo mẫu:

| Mục tiêu Deploy | Địa chỉ / Thiết bị | Phiên bản / Bản dựng | Kết quả Kiểm tra | Trạng thái |
|---|---|---|---|---|
| **Pre-Deploy Git Check** | GitLab / GitHub Remote | `vcloud-sync check` | Đồng bộ mới nhất | ⬜ PENDING |
| **Flutter Debug APK** | `build/.../app-debug.apk` | Build mới nhất từ main | Build thành công | ⬜ PENDING |
| **Điện thoại Vivo V2116** | ADB Wireless `192.168.1.6/8` | Cài đặt & Khởi chạy | App mở ổn định | ⬜ PENDING |
| **Redroid Local Server** | `192.168.1.100:5555` | Cài đặt & Khởi chạy | App mở ổn định | ⬜ PENDING |
| **Waydroid Máy cá nhân** | Localhost (`waydroid`) | Cài đặt & Khởi chạy | App mở ổn định | ⬜ PENDING |
| **Backend Odoo 17 & 19** | `192.168.1.100` (8069/1700/1900) | LAN Direct Sync & Restart | HTTP 200 OK | ⬜ PENDING |
| **Post-Deploy Git Push** | Remote Repositories | Đẩy đầy đủ code + docs | Up-to-date | ⬜ PENDING |

================================================================================
🥊 [ANTI-SYCOPHANCY & CALIBRATED CONFIDENCE PROTOCOL]
1. **CLAIM ≠ FACT**: Mọi tuyên bố "đã cài app" hoặc "đã deploy" chỉ được công nhận khi có command output xác nhận `Success` và app package `com.mobile.vloud` đang chạy.
2. **Thang đo L0-L5**: Cấm nhảy cấp. Chỉ báo `L4 VERIFIED` khi có log runtime kiểm tra HTTP 200 từ Backend và `sys.boot_completed` từ thiết bị.
3. **Cấm số ảo**: Không dùng từ ngữ "hoàn hảo", "100%". Báo cáo trung thực tình trạng kết nối từng thiết bị (nếu thiết bị nào tắt nguồn/mất mạng thì ghi rõ `Offline / Bỏ qua`).
