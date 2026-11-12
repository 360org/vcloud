# Hướng Dẫn Sử Dụng & Cấu Hình Thiết Bị Thật Vivo V2116 Cho AI Agents & UI Test

> **Tài liệu chuẩn hóa hạ tầng kiểm thử Mobile**: Cấu hình kết nối ADB Wireless Debugging, kịch bản kiểm thử cuộc gọi thoại 2 chiều WebRTC & thông báo FCM Push trên thiết bị Android vật lý.  
> **Áp dụng cho**: Lead Agent, Tester Functional, Dev Mobile, Dev Infra.

---

## 1. Thông Số Phần Cứng & Mạng (Device Profile)

| Thuộc tính | Giá trị chi tiết | Ghi chú |
|---|---|---|
| **Model máy** | `Vivo V2116` (vivo 2116) | Android Smartphone vật lý |
| **Hệ điều hành** | Android 11 (API level 30) / Funtouch OS | Hỗ trợ ADB Pair TLS |
| **Độ phân giải màn hình** | 1080 x 2400 pixels (Tỷ lệ 20:9) | Màn hình AMOLED |
| **Mật độ điểm ảnh (DPI)** | 440 dpi | Mật độ chuẩn hiển thị |
| **Địa chỉ IP Wi-Fi nội bộ** | `192.168.1.8` | Cố định qua DHCP router |
| **Giao thức kết nối** | ADB Wireless Debugging (TLS Pairing) | Không cần cắm cáp USB |
| **Cổng kết nối ADB** | Port động (vd: `42127`, `40387`...) | Tra cứu trên màn hình Gỡ lỗi không dây |
| **Package ứng dụng** | `com.mobile.vloud` | App VCloud Mobile |
| **Tài khoản kiểm thử chính** | `demo` (Demo User - partner_id: 6913) | Chuyên dùng nhận cuộc gọi |

---

## 2. Kịch Bản Kiểm Thử Cuộc Gọi 2 Chiều (2-Way Call Topology)

Mô hình kiểm thử phân tách 2 thiết bị độc lập cùng kết nối vào mạng nội bộ 360 CORP:

```text
┌──────────────────────────────────────────────┐        ┌──────────────────────────────────────────────┐
│       THIẾT BỊ 1: MÁY TÍNH / LOCAL SERVER    │        │       THIẾT BỊ 2: ĐIỆN THOẠI THẬT VIVO       │
│  - Môi trường: Redroid Android 11 Docker     │        │  - Model: Vivo V2116 (Android 11)           │
│  - Địa chỉ: 192.168.1.100:5555               │        │  - Địa chỉ: 192.168.1.8:<connect_port>      │
│  - Tài khoản: admin (Chau, Le Ba - ID: 3)    │ ◄────► │  - Tài khoản: demo (Demo User - ID: 6913)   │
│  - Vai trò: Người gọi (Caller) / Caller B    │  WebRTC│  - Vai trò: Người nhận (Callee) / Callee A   │
│  - Màn hình: Scrcpy / Terminal ADB           │  + FCM │  - Màn hình: Màn hình thật trên tay Sếp      │
└──────────────────────────────────────────────┘        └──────────────────────────────────────────────┘
```

---

## 3. Quy Trình Kết Nối ADB Không Dây (Wireless Pairing)

### Bước 1: Thao tác trên điện thoại Vivo
1. Vào **Cài đặt (Settings)** ➔ **Hệ thống (System)** ➔ **Tùy chọn nhà phát triển (Developer options)**.
2. Bật mục **Gỡ lỗi không dây (Wireless debugging)** ➔ Cho phép kết nối với Wi-Fi hiện tại.
3. Nhấn vào dòng **Ghép nối thiết bị bằng mã ghép nối (Pair device with pairing code)**.
4. Màn hình sẽ hiển thị:
   - Địa chỉ IP & Cổng ghép nối: `192.168.1.8:<pairing_port>`
   - Mã ghép nối Wi-Fi (6 chữ số): `XXXXXX`

### Bước 2: Thực thi lệnh ghép nối trên máy Mac/Linux
```bash
# Ghép nối bảo mật TLS (chỉ cần chạy lần đầu hoặc khi đổi mạng)
adb pair 192.168.1.8:<pairing_port> <pairing_code>
# Ví dụ: adb pair 192.168.1.8:40387 458566
```

### Bước 3: Kết nối ADB điều khiển
```bash
# Kết nối cổng điều khiển (hiển thị ở màn hình chính Gỡ lỗi không dây)
adb connect 192.168.1.8:<connect_port>
# Ví dụ: adb connect 192.168.1.8:42127

# Xác minh thiết bị đã sẵn sàng
adb devices -l
# Kết quả mong đợi:
# 192.168.1.8:42127    device product:2116 model:V2116 device:2116
```

---

## 4. Lệnh Điều Khiển & Tự Động Hóa Dành Cho AI Agent

### 4.1 Cài đặt & Cập nhật APK mới nhất
```bash
# Gỡ bản cũ nếu có xung đột chữ ký (Signature mismatch)
adb -s 192.168.1.8:<port> uninstall com.mobile.vloud

# Cài đặt APK Debug mới nhất
adb -s 192.168.1.8:<port> install -r /media/tanma/DATA/save/mobile_versions/vclients/build/app/outputs/flutter-apk/app-debug.apk
```

### 4.2 Khởi chạy & Điều hướng ứng dụng
```bash
# Khởi chạy App VCloud Mobile
adb -s 192.168.1.8:<port> shell am start -n com.mobile.vloud/com.mobile.vloud.MainActivity

# Đưa ứng dụng xuống chạy ngầm (Home) để test FCM Wake-up Push
adb -s 192.168.1.8:<port> shell input keyevent 3

# Mở màn hình Cài đặt quyền thông báo
adb -s 192.168.1.8:<port> shell am start -a android.settings.APP_NOTIFICATION_SETTINGS --es android.provider.extra.APP_PACKAGE com.mobile.vloud
```

### 4.3 Chụp ảnh màn hình làm bằng chứng (Evidence Ledger)
```bash
# Chụp ảnh và tải về máy
adb -s 192.168.1.8:<port> shell screencap -p /sdcard/vivo_evidence.png
adb -s 192.168.1.8:<port> pull /sdcard/vivo_evidence.png /media/tanma/DATA/save/mobile_versions/.claude/agent_state/evidence_vivo_screen.png
```

### 4.4 Bắt Logcat CallKit & WebRTC
```bash
# Bắt log CallKit & cuộc gọi đến theo thời gian thực
adb -s 192.168.1.8:<port> logcat -c
adb -s 192.168.1.8:<port> logcat -s flutter:V FlutterCallkitIncoming:V flutter_webrtc:V
```

---

## 5. Quy Chuẩn Xử Lý Sự Cố CallKit & Giao Diện Cuộc Gọi Đến

Khi kiểm thử cuộc gọi thoại giữa Redroid (`admin`) và Vivo (`demo`), nếu trên điện thoại Vivo **không hiện giao diện nhận/từ chối cuộc gọi**, cần kiểm tra 4 điểm cốt lõi:

1. **Quyền "Hiển thị đè lên ứng dụng khác" (Appear on top / Overlay Permission)**:
   - Trên Funtouch OS của Vivo, mặc định quyền hiển thị toàn màn hình bị chặn chặt.
   - Thao tác: `Cài đặt` ➔ `Ứng dụng & thông báo` ➔ `Quyền truy cập đặc biệt` ➔ `Hiển thị trên các ứng dụng khác` ➔ Tìm `Vcloud` ➔ **Cho phép**.
2. **Quyền "Khởi chạy nền & Tự khởi động" (Autostart)**:
   - Bật tự khởi động để FCM Service có thể đánh thức CallKit khi app đang chạy ngầm hoặc tắt màn hình.
3. **Kênh thông báo "Cuộc gọi đến" (Notification Channel)**:
   - Kênh `Cuộc gọi đến` phải đặt mức ưu tiên cao nhất (`Khẩn cấp` / `Âm thanh và hiển thị trên màn hình`).
4. **Cơ chế Fallback Trong App (In-App Incoming Call Banner)**:
   - Khi app đang mở ở Foreground, `ChatV2CallListener` kích hoạt banner nổi từ mép trên với 2 nút lớn:
     - Nút đỏ (0xFFEF4444): **Từ chối (Reject)**
     - Nút xanh lá (0xFF10B981): **Trả lời (Accept)** ➔ Mở `ChatV2CallScreen`.
