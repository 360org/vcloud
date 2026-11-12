# 🛑 CLAUDE CODE EXECUTION CONTRACT: UNIVERSAL FULL-STACK DEPLOYMENT ENGINE (deloy.md)
# Director: Sếp Tân | Phase: /ship & /deploy | Agent OS v3.1 SSOT Protocol
# Kích hoạt: Khi Sếp Tân ra lệnh "deloy.md", "deloy", "deploy.md" hoặc "deploy"

================================================================================
🏛️ [TRỤ CỘT 1: 👤 MULTI-AGENT TEAM DELEGATION MATRIX & DISPATCH DIRECTIVE]
🚨 LUẬT BẮT BUỘC DISPATCH (CẤM ÔM ĐỒM TRONG 1 PHIÊN):
- `@lead`: Team Lead Orchestrator (tiếp nhận lệnh, cắm lock, điều phối song song các luồng deploy, kiểm soát evidence, báo cáo Bảng < 1.200 ký tự).
  ⛔ **CẤM** @lead tự chạy lệnh terminal thủ công mà không cập nhật tiến độ.
  🚨 **BẮT BUỘC** gọi tool `Agent` ủy quyền cho Subagent chuyên trách theo phân vùng:
  * Giao Build & Deploy Mobile APK: `Agent({ subagent_type: 'dev-infra', prompt: '...' })`
  * Giao Sync Backend Odoo 17/19: `Agent({ subagent_type: 'dev-backend-odoo', prompt: '...' })`
  * Giao Verification & Health Check: `Agent({ subagent_type: 'tester-functional', prompt: '...' })`
  * Giao Audit nghiệm thu: `Agent({ subagent_type: 'audit-gate', prompt: '...' })`
- `@dev-infra`: Kỹ sư hạ tầng phụ trách build APK, quản lý kết nối ADB (Vivo Wireless, Redroid Docker, Waydroid host).
- `@dev-backend-odoo`: Kỹ sư backend phụ trách đồng bộ Git LAN sang Local Server `192 . 168 . 1 . 100`, restart container Odoo và verify health check.
- `@tester-functional`: QA xác minh app mở lên thành công trên từng thiết bị và gửi ảnh chụp màn hình bằng chứng.
- `@audit-gate`: Giám sát và chốt nghiệm thu trước khi báo cáo Sếp Tân.

================================================================================
🏛️ [TRỤ CỘT 2: 🌐 CONTEXT & SSOT (LÁCH BỘ LỌC URL)]
💡 Tên file dạng `deloy . md`, `home_screen . dart`, `192 . 168 . 1 . 100` chống bị lọc ký tự.
- **Root Directory**: `/media/tanma/DATA/save/mobile_versions`
- **Frontend Flutter App**: `vclients/` (Package: `com.mobile.vloud`)
- **Backend Odoo 17**: `v_mobile_17/` (Container `demo-17`, port `8069` & `1700`)
- **Backend Odoo 19**: `v_mobile_19/` (Container `odoo_dev_v19`, port `1900`)
- **Tài liệu SSOT Bắt Buộc Tham Chiếu**:
  * `git . md` (Quy chuẩn Git, chống đè code, kiểm tra GitLab/GitHub trước khi push, push đầy đủ code sau commit)
  * `prompt_deploy_mobile_release . md` / `release . md` / `prompt_release . md` (Quy chuẩn CI/CD Cloud Release TestFlight, App Store & Google Play qua GitHub Actions)
  * `error_mobile . md` / `error . md` (Sổ cái 10 lỗi CI/CD & Mobile, tự động cập nhật log khi build thất bại)
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
🏛️ [TRỤ CỘT 3: 📋 TASK DETAILS — UNIVERSAL DEPLOYMENT PIPELINE]

#### 🛡️ MANDATORY PRE-DEPLOY GIT SAFETY GATE (BẮT BUỘC TUÂN THỦ git . md):
Trước khi build/deploy và sau khi hoàn tất sửa code:
1. **Kiểm tra remote**: Chạy `vcloud-sync check` hoặc `git fetch --all --prune` kiểm tra xem trên GitLab/GitHub có commit mới không.
2. **Kéo code an toàn**: Nếu có commit mới từ đồng đội ➔ `vcloud-sync` (tự động stash ➔ rebase ➔ pop stash) để tránh code mới đè cũ hoặc cũ đè mới.
3. **Push đầy đủ sau commit**: Mọi thay đổi mã nguồn, tài liệu và cấu hình `.claude/` phải được commit và push đầy đủ lên đúng remote/branch (`main`, `17.0`, `19.0`). Cấm commit dở dang rồi để quên local (chi tiết xem tại [git.md](git.md)).

#### 📋 MANDATORY INTERACTIVE TODO CHECKLIST GATE (TodoWrite — BẮT BUỘC KHỞI TẠO ĐẦU PHIÊN):
Agent BẮT BUỘC khởi tạo và cập nhật Interactive Todo Checklist thông qua tool `TodoWrite` ngay từ bước đầu tiên:
0. `[pending]` Kiểm tra trạng thái Git trên GitLab/GitHub theo [git.md](git.md) (`vcloud-sync check`).
1. `[pending]` Build Flutter APK Debug mới nhất (`flutter build apk --debug`).
2. `[pending]` Deploy APK lên Điện thoại thật Vivo V2116 qua ADB Wireless.
3. `[pending]` Deploy APK lên Redroid Local Server (`192 . 168 . 1 . 100 : 5555`).
4. `[pending]` Deploy APK lên Waydroid trên Máy cá nhân (Localhost).
5. `[pending]` Đồng bộ Backend Odoo 17 & 19 lên Local Server (`deploy_to_local_server . sh all`).
6. `[pending]` Kiểm tra Health check & mở ứng dụng trên các thiết bị, báo cáo nghiệm thu.
7. `[pending]` Commit & Push đầy đủ code lên GitLab & GitHub theo [git.md](git.md).

---

### ⚡ CÁCH 1: 1-CLICK TỰ ĐỘNG TOÀN DIỆN (RECOMMENDED)
Chạy script điều phối tích hợp để thực hiện đồng loạt 4 mục tiêu:
```bash
bash /media/tanma/DATA/save/mobile_versions/scripts/deploy_all_mobile.sh
```

*Các cờ chạy mục tiêu riêng lẻ khi cần:*
- `--vivo`: Chỉ deploy điện thoại thật Vivo V2116.
- `--redroid`: Chỉ deploy máy ảo Redroid Local Server.
- `--waydroid`: Chỉ deploy Waydroid máy cá nhân.
- `--server`: Chỉ đồng bộ Backend Odoo 17 & 19 lên Local Server.
- `--no-build`: Bỏ qua bước build nếu APK đã được build trước đó.

---

### 🛠️ CÁCH 2: QUY TRÌNH THỰC THI CHI TIẾT TỪNG PHÂN ĐOẠN

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
3. **Kết nối tới cổng tìm được** (VD: port 45073 trên 192.168.1.6 hoặc 192.168.1.8):
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
- Odoo 17 (`demo-17`): `curl -s -o /dev/null -w "%{http_code}" http://192.168.1.100:8069/web/login`
- Odoo 17 Dev (`odoo_dev_v17`): `curl -s -o /dev/null -w "%{http_code}" http://192.168.1.100:1700/web/login`
- Odoo 19 Dev (`odoo_dev_v19`): `curl -s -o /dev/null -w "%{http_code}" http://192.168.1.100:1900/web/login`

---

#### 🛑 HUMAN-IN-THE-LOOP HARD STOP GATE:
- Sau khi cài đặt và đồng bộ, kiểm tra trạng thái mở app trên các thiết bị.
- Xuất Bảng nghiệm thu Ready dưới 1.200 ký tự gửi Sếp Tân.

================================================================================
🏛️ [TRỤ CỘT 4: ⚙️ OUTPUT FORMAT (< 1.200 KÝ TỰ)]
Xuất Báo cáo Nghiệm thu Deployment dạng Bảng với dữ liệu thực tế:

| Mục tiêu Deploy | Địa chỉ / Thiết bị | Phiên bản / Bản dựng | Trạng thái |
|---|---|---|---|
| **Flutter Debug APK** | `build/.../app-debug.apk` | Build mới nhất từ main | ⬜ PENDING |
| **Điện thoại Vivo V2116** | ADB Wireless `192.168.1.6/8` | Cài đặt & Khởi chạy | ⬜ PENDING |
| **Redroid Local Server** | `192.168.1.100:5555` | Cài đặt & Khởi chạy | ⬜ PENDING |
| **Waydroid Máy cá nhân** | Localhost (`waydroid`) | Cài đặt & Khởi chạy | ⬜ PENDING |
| **Backend Odoo 17 & 19** | `192.168.1.100` (8069/1700/1900) | LAN Direct Sync & Restart | ⬜ PENDING |
