---
name: visual-qa-rule
description: Quy tắc bắt buộc Antigravity xuất bảng danh sách kiểm tra (Visual QA Checklist) và chặn tự động kích hoạt trình duyệt ngầm để tiết kiệm hạn ngạch (quota).
---

# 🎯 QUY TẮC PHỐI HỢP KIỂM THỰ TRỰC QUAN (VISUAL QA RULE)

## 📌 1. MỤC TIÊU (OBJECTIVE)
Quy tắc này nhằm **tối ưu hóa 100% hạn ngạch (quota) tính toán và token** của bạn trong các phiên làm việc sửa đổi giao diện (UI) bằng cách chặn đứng hành vi tự ý khởi chạy trình duyệt ngầm (BrowserMCP, Playwright, hoặc CDP Browser Agent) của Antigravity. Quy tắc này ép buộc hệ thống luôn phải hoạt động theo mô hình **Human-in-the-Loop (QA thủ công có kiểm soát qua Gemini trên Chrome Side Panel)**.

---

## 🚫 2. CẤM KHỞI CHẠY TRÌNH DUYỆT TỰ ĐỘNG (STRICT BROWSER BLOCK)
1. **KHÔNG tự ý gọi công cụ trình duyệt:** Tuyệt đối không được tự động kích hoạt các công cụ như `browsermcp`, `playwright-cli`, hoặc trình duyệt Chromium tích hợp trừ khi người dùng ra lệnh trực tiếp bằng từ khóa chính xác: *"sử dụng trình duyệt ngầm"* hoặc *"chạy Playwright tự động"*.
2. **Không tự phỏng đoán giao diện:** Tránh việc tự biên dịch code rồi tự bật browser để kiểm tra. Hãy tin tưởng vào mã nguồn đã sửa và giao nhiệm vụ kiểm tra trực quan cho người dùng.

---

## 📝 3. QUY TRÌNH XUẤT CHECKLIST KIỂM THỰ (MANDATORY CHECKLIST GENERATION)
Sau khi hoàn thành bất kỳ tác vụ chỉnh sửa giao diện nào (Frontend Flutter `vclients` hoặc các giao diện XML/Web của Odoo Backend `v_mobile`), Antigravity **bắt buộc** phải dừng lại và xuất ra một bảng **Danh sách kiểm tra trực quan (Visual QA Checklist)** định dạng Markdown súc tích theo cấu trúc sau:

### 📊 BẢNG TIÊU CHÍ ĐÁNH GIÁ TRỰC QUAN (VISUAL QA CHECKLIST)

| Test ID | Thành phần UI | Vị trí File sửa đổi | Hành vi mong đợi (Expected Behavior) | Cách thức kiểm tra thủ công (User Action) | Trạng thái |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **QA-VIS-01** | [Ví dụ: Avatar Fallback] | `avatar.py` & `chat_avatar.dart` | Hiển thị chữ cái đầu tiên của tên khi không có ảnh, vòng tròn màu sắc ngẫu nhiên. | Mở phòng chat trống ảnh, quan sát avatar. | `Chờ duyệt` |
| **QA-VIS-02** | [Ví dụ: Unread Badge] | `chat.py` & `chat_sync.dart` | Badge đỏ hiển thị số unread chính xác ở Home & Footer. | Gửi tin nhắn nháp từ Odoo, xem badge trên app. | `Chờ duyệt` |

### 🧭 Hướng dẫn kiểm thử nhanh cho người dùng:
1. Chạy ứng dụng local của bạn (Ví dụ: `flutter run -d chrome`).
2. Mở bảng điều khiển **Gemini Side Panel** trên trình duyệt Chrome đang hiển thị app.
3. Copy bảng Checklist phía trên dán vào Gemini Chrome và ra lệnh: *"Hãy chụp ảnh màn hình hiện tại, đối chiếu với bảng Checklist này và chấm điểm PASS/FAIL cho tôi."*
4. Dán kết quả (`PASS`/`FAIL`) của Gemini Chrome vào ô chat này để tôi tiếp tục xử lý.

---

## 🔄 4. VÒNG LẶP SỬA LỖI & DUYỆT CODE (REWORK & APPROVAL LOOP)
* **Nếu nhận phản hồi `FAIL`:** Đọc kỹ mô tả lỗi trực quan từ kết quả quét của Gemini Chrome do người dùng dán vào, phân tích nguyên nhân tận gốc, tiến hành vá code tại local và tạo lại bảng Checklist mới để kiểm thử lại từ đầu.
* **Nếu nhận phản hồi `PASS`:** Ghi nhận trạng thái hoàn thành vào tài liệu tiến độ (`walkthrough.md` hoặc `task.md`) và sẵn sàng cho các công đoạn đóng gói, commit Git tiếp theo.
