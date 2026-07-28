# 📱 Google Play Store Listing Metadata - VCloud Mobile

Tài liệu này chứa toàn bộ thông tin công bố (Store Listing) và khai báo quy định cho ứng dụng **VCloud Mobile** trên Google Play Console.

---

## 📌 1. Thông Tin Cơ Bản (App Details)

- **Tên ứng dụng (App Title)** *(Tối đa 30 ký tự)*:
  `VCloud Mobile`

- **Mô tả ngắn (Short Description)** *(Tối đa 80 ký tự)*:
  `Giải pháp quản lý doanh nghiệp: Điểm danh GPS, Timesheet, Ticket & Chat.`

- **Mô tả đầy đủ (Full Description)** *(Tối đa 4000 ký tự)*:
```text
VCloud Mobile là ứng dụng quản trị doanh nghiệp toàn diện, tích hợp trực tiếp với hệ thống Odoo ERP, giúp tối ưu hóa hiệu suất làm việc của nhân viên và quy trình vận hành doanh nghiệp.

TÍNH NĂNG NỔI BẬT:

📍 ĐIỂM DANH GPS THỜI GIAN THỰC
- Điểm danh vào/ra ca làm việc chính xác bằng vị trí GPS và chụp ảnh xác thực.
- Tự động ghi nhận thời gian làm việc, tăng tính minh bạch và chính xác.

⏱️ QUẢN LÝ BẢNG CÔNG & TIMESHEET
- Theo dõi nhật ký làm việc, số giờ chấm công và ca làm việc chi tiết.
- Xem báo cáo tổng hợp ngày, tuần, tháng nhanh chóng.

🎫 HỆ THỐNG YÊU CẦU & SUPPORT TICKET
- Gửi yêu cầu hỗ trợ, xin nghỉ phép, duyệt đề xuất dễ dàng.
- Theo dõi trạng thái xử lý ticket và tương tác với bộ phận quản lý.

💬 CHAT NỘI BỘ DOANH NGHIỆP
- Trò chuyện trực tiếp 1-1 hoặc theo nhóm dự án.
- Trao đổi công việc bảo mật, gửi tệp tin và thông báo tức thì (Push Notification).

🔒 BẢO MẬT & ĐỘ TÍNH CỦA DỮ LIỆU
- Mã hóa dữ liệu truyền tải theo tiêu chuẩn SSL/TLS.
- Tích hợp lưu trữ bảo mật thiết bị (Secure Storage) bảo vệ phiên đăng nhập.

Phát triển bởi V360S JOINT STOCK COMPANY.
Website: https://vuahethong.com
Hỗ trợ: admin@w360s.com / chaulb@icloud.com
```

---

## 🎨 2. Tài Nguyên Đồ Họa (Graphics & Assets)

- **App Icon (Khai báo Store Icon)**:
  - File: `image/android_playstore/vcloud_playstore_icon_512x512.png`
  - Kích thước: `512 x 512 px` (PNG 32-bit alpha)

- **Feature Graphic (Ảnh bìa nổi bật)**:
  - File: `image/android_playstore/vcloud_playstore_feature_graphic_1024x500.png`
  - Kích thước: `1024 x 500 px` (PNG/JPEG)

- **Phone Screenshots (Ảnh chụp màn hình điện thoại - 5 ảnh)**:
  - Thư mục: `image/`
  - Kích thước: `1242 x 2688 px`
  - Danh sách ảnh:
    1. `01_login_screen.png` - Màn hình đăng nhập doanh nghiệp
    2. `02_home_screen.png` - Trang chủ & Chức năng điểm danh GPS
    3. `03_timesheet_screen.png` - Nhật ký chấm công & Timesheet
    4. `04_ticket_screen.png` - Quản lý Ticket & Yêu cầu
    5. `05_chat_screen.png` - Trò chuyện & Thảo luận nội bộ

---

## 🔒 3. Khai Báo Bảo Mật Dữ Liệu (Data Safety Questionnaire)

Khai báo bắt buộc trên Google Play Console:

| Loại dữ liệu (Data Type) | Mục đích sử dụng (Purpose) | Có chia sẻ với bên thứ 3? | Có bắt buộc? |
|---|---|---|---|
| **Vị trí chính xác (Precise Location)** | Chức năng điểm danh GPS (App functionality) | Không (No) | Bắt buộc khi điểm danh |
| **Địa chỉ Email (Email Address)** | Định danh tài khoản & Đăng nhập | Không (No) | Bắt buộc |
| **Họ và Tên (Name)** | Hiển thị hồ sơ nhân viên trong tổ chức | Không (No) | Bắt buộc |
| **Hình ảnh/Video (Photos/Videos)** | Ảnh xác thực điểm danh & Đính kèm Ticket | Không (No) | Tùy chọn khi tải file |

- **Thu thập dữ liệu**: Có (Data Collection = Yes).
- **Mã hóa truyền tải**: Có, dữ liệu được mã hóa trong quá trình di chuyển (Encryption in transit).
- **Yêu cầu xóa dữ liệu**: Người dùng có thể yêu cầu xóa tài khoản/dữ liệu bằng cách gửi email về `admin@w360s.com`.

---

## 🏷️ 4. Phân Loại & Thông Tin Liên Hệ (Categorization & Contact)

- **Loại ứng dụng (App type)**: Ứng dụng (App)
- **Danh mục (Category)**: Doanh nghiệp / Hiệu suất (Business / Productivity)
- **Email liên hệ (Support Email)**: `admin@w360s.com`
- **Số điện thoại hỗ trợ**: `+84964645229`
- **Website hỗ trợ (Support URL)**: `https://vuahethong.com`
- **URL Chính sách bảo mật (Privacy Policy URL)**: `https://vuahethong.com`

---

## 🔞 5. Xếp Hạng Nội Dung (Content Rating)

Khi hoàn thành bảng hỏi IARC trên Google Play Console:
- Chọn loại hình: **Business / Utility**.
- Các câu hỏi về bạo lực, tình dục, cờ bạc, nội dung khiêu dâm: **Không (No)**.
- Kết quả xếp hạng dự kiến: **PEGI 3** / **USK 0** / **Everyone (Mọi lứa tuổi)**.
