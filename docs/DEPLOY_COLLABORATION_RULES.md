# 🚀 QUY TẮC PHỐI HỢP & QUY TRÌNH TRIỂN KHAI HỆ THỐNG (DEPLOY COLLABORATION RULES)
## Hệ Sinh Thái VCloud Mobile App & Odoo Backend (AIaC 3.0 Standard)

> [!IMPORTANT]
> **Tài liệu quy chuẩn bắt buộc**: Áp dụng cho mọi phiên làm việc phối hợp giữa **anh Tân**, **Sếp Châu**, **Đội vận hành (Backend Deployment Lead)** và **AI Assistant**.

---

## 👥 1. PHÂN CÔNG VAI TRÒ TRIỂN KHAI (ROLES & RESPONSIBILITIES)

| Vai trò | Phụ trách | Phạm vi & Nguồn build | Nhiệm vụ chính |
| :--- | :--- | :--- | :--- |
| **Anh Tân** | **Frontend Deployment Lead** | Nguồn `release/ios-appstore` (`vclients`) | - Trực tiếp kiểm tra giao diện và đồng bộ mã nguồn vào release mobile.<br>- Kích hoạt **GitHub Actions CI/CD** đóng gói bản build TestFlight / App Store cho iPhone 13. |
| **Đội vận hành & Sếp Châu** | **Backend Deployment Lead** | Nguồn `17.0` (`v_mobile`) | - Review audit mã nguồn Backend trên nguồn `17.0`.<br>- Thực hiện quy trình nâng cấp Odoo Module Zero-Downtime trên máy chủ SaaS (`vuahethong.net`). |

---

## 🛑 2. QUY TẮC VÀNG DÀNH CHO ĐỘI VẬN HÀNH KHI DEPLOY BACKEND

> [!CAUTION]
> ### ⚠️ CẢNH BÁO TỐI QUAN TRỌNG: TUYỆT ĐỐI KHÔNG TỰ Ý ĐỔI LOGIC MÃ NGUỒN TRONG KHI DEPLOY
> 
> Trong quá trình audit và deploy nguồn backend release lên server:
> 1. **KHÔNG TỰ Ý SỬA FILE / THAY ĐỔI LOGIC ĐÃ QUA KIỂM TOÁN**:
>    - Tuyệt đối không thay đổi cấu trúc API JSON payload, tham số endpoint, cơ chế SQL query O(1), pagination, DTO mapping hoặc state cache.
>    - **Hậu quả nghiêm trọng**: Nếu Đội vận hành tự ý thay đổi logic backend hoặc contract, toàn bộ **hệ thống test suite (207 tests)** trên máy anh Tân sẽ bị **FAIL (LỖI ĐỎ)** ngay lập tức. Khi test đỏ, luồng **GitHub Actions CI/CD của Frontend sẽ tự động BỊ CHẶN ĐỨNG (Build Failed)** và **HOÀN TOÀN KHÔNG THỂ DEPLOY hay phát hành bản dựng mới được**.
> 2. **QUY TẮC ĐÓNG GÓP Ý KIẾN (SUGGESTION ONLY)**:
>    - Nếu Đội vận hành thấy chỗ nào trong code chưa ưng ý hoặc có giải pháp tối ưu hơn: **BẮT BUỘC CHỈ GHI GÓP Ý MINH BẠCH VÀO `docs/AUDIT_REPORT.md` VÀ `docs/CHANGELOGS.md`**.
>    - Tuyệt đối **KHÔNG** sửa thẳng vào mã nguồn trước khi được anh Tân và team đồng thuận.

---

## 🔄 3. QUY TRÌNH ĐỒNG BỘ 3 BƯỚC (END-TO-END DEPLOYMENT LIFECYCLE)

```text
┌────────────────────────────────────────────────────────────────────────┐
│ 1️⃣ BƯỚC 1 — ANH TÂN DEPLOY FRONTEND:                                   │
│    - Anh Tân merge code vào nguồn `release/ios-appstore`.              │
│    - Kích hoạt GitHub Actions CI/CD chạy 207 tests (PASS 100%)         │
│      và tự động đóng gói IPA tải lên Apple TestFlight.                 │
└──────────────────────────────────┬─────────────────────────────────────┘
                                   │
┌──────────────────────────────────▼─────────────────────────────────────┐
│ 2️⃣ BƯỚC 2 — ĐỘI VẬN HÀNH DEPLOY BACKEND:                               │
│    - Đội vận hành checkout nguồn `17.0` (đã merge).                     │
│    - Review audit và thực thi lệnh Zero-Downtime Upgrade trên Odoo     │
│      SaaS (vuahethong.net) theo đúng 9 bước chuẩn AIaC.                │
└──────────────────────────────────┬─────────────────────────────────────┘
                                   │
┌──────────────────────────────────▼─────────────────────────────────────┐
│ 3️⃣ BƯỚC 3 — KIỂM CHỨNG TRÊN IPHONE 13 (LIVE RUNTIME):                 │
│    - iPhone 13 của anh Tân nhận bản cập nhật TestFlight mới.           │
│    - App kết nối vào Backend Odoo vừa nâng cấp -> Khớp 100% API,       │
│      mọi tính năng chạy mượt mà, không lỗi phân quyền hay sai lệch giờ.│
└────────────────────────────────────────────────────────────────────────┘
```

---

## 📋 4. DANH MỤC LOGIC CỐT LÕI BẢO TOÀN TUYỆT ĐỐI

Mọi thay đổi trên cả Frontend và Backend **BẮT BUỘC** duy trì các trụ cột kỹ thuật sau:
1. **Local Cache First**: Phản hồi tức thì trong `< 1.2ms` từ RAM Cache, không chặn Main UI Thread.
2. **Batch SQL Prefetch `O(1)`**: Lấy dữ liệu tin nhắn, attachments, avatar và đếm unread bằng batch SQL duy nhất, triệt tiêu hoàn toàn lỗi N+1 queries.
3. **GPS Location Sharing**: Định dạng chuẩn quốc tế `📍 Vị trí: https://maps.google.com/?q={lat},{lng}` và render thẻ vị trí 1 chạm mở bản đồ.
4. **Pagination Chuẩn Telegram / Zalo**: Nạp 80 kênh đầu tiên + 35 tin nhắn gần nhất; Lazy load vô tận khi cuộn ngược.
5. **Async Safety**: Hủy toàn bộ Timer/Stream tại `dispose()` và kiểm tra `if (!mounted) return;` sau mỗi `await`.

---
*Tài liệu được lưu trữ chính thức tại:* [`docs/DEPLOY_COLLABORATION_RULES.md`](docs/DEPLOY_COLLABORATION_RULES.md)
