# 📘 DANH MỤC TÍNH NĂNG TOÀN DIỆN VCLOUD MOBILE APP & ODOO BACKEND (FEATURES CATALOG)

> **Hệ sinh thái**: VCloud Mobile App (Flutter Client) & Odoo Mobile Addon (`vmobile` - Odoo 17 & Odoo 19)  
> **Phiên bản chuẩn hóa**: `v2.9.12` (Build 144)  
> **Nguồn sự thật duy nhất (Single Source of Truth - SSOT)**: Tài liệu đặc tả chức năng toàn diện cho 80 tính năng thuộc 6 phân hệ nghiệp vụ chuẩn mực.

> 💡 **HƯỚNG DẪN KHI AUDIT MÃ NGUỒN ODOO BACKEND**:
> Sau khi pull nhánh `17.0` (`v_mobile_17`) hoặc `19.0` (`v_mobile_19`), người vận hành cần thực hiện nâng cấp (upgrade) module **`vmobile`** trên Odoo Server để nạp toàn bộ các bản vá API và route mới nhất:
> ```bash
> odoo-bin -u vmobile -d <database_name>
> ```

---

## 📑 BẢNG TỔNG QUAN 6 PHÂN HỆ NGHIỆP VỤ (80 TÍNH NĂNG)

| STT | Phân Hệ Nghiệp Vụ | Số Lượng Tính Năng | Phạm Vi Kiến Trúc |
| :---: | :--- | :---: | :--- |
| **1** | **Xác thực & Quản trị Phiên (Auth & Multi-DB)** | 8 tính năng | Flutter Auth, JWT Token, Odoo Session, Multi-DB Resolver |
| **2** | **Quản lý Thời gian & Chấm công (Timesheet & HR)** | 12 tính năng | GPS Geofencing, `hr.attendance`, `account.analytic.line`, Stopwatch |
| **3** | **Giao tiếp Nội bộ & Hội thoại Đa phương tiện (Chat V2 & Media)** | 28 tính năng | Odoo Discuss, WebRTC Audio, Coturn TURN, WebSocket Bus, SAF, Clean Reply, Mute |
| **4** | **Quản lý Công việc & Bảng Điều khiển (Dashboard & Tasks)** | 9 tính năng | `project.task`, Subtasks Checklist, SWR Cache, Notification Center |
| **5** | **Hỗ trợ Kỹ thuật & Phiếu Dịch vụ (Helpdesk Tickets)** | 14 tính năng | `helpdesk.ticket`, SLA Tracker, Odoo Chatter, In-App Attachment Viewer |
| **6** | **Hồ sơ Cá nhân & Tiện ích Hệ thống (Profile & Settings)** | 9 tính năng | `res.users`, Dark Theme, Cache Cleaner, 4-Tier Secure Logout |

---

## 🔐 PHÂN HỆ 1: XÁC THỰC & QUẢN TRỊ PHIÊN (8 TÍNH NĂNG)

### 1.1. Đăng nhập Pre-Auth & Xác thực Chứng thực Hai bước
- Cơ chế xác thực sơ bộ (Pre-Auth) kiểm tra thông tin tài khoản và mật khẩu trực tiếp qua API `/api/v1/mobile/auth/login`.
- Tự động phát hiện loại tài khoản (Internal User hoặc Portal User) và danh sách cơ sở dữ liệu mà người dùng được phép truy cập.
- Trả về mã lỗi chuẩn mực HTTP 401 khi sai thông tin xác thực, loại bỏ nguy cơ lộ lọt thông tin phân tích hệ thống.

### 1.2. Lựa chọn Cơ sở Dữ liệu Đa Tenant (Multi-Database Selector)
- Tự động hiển thị hộp thoại chọn cơ sở dữ liệu nếu người dùng có tài khoản trên từ 2 database trở lên trên cùng máy chủ.
- Lọc triệt để và chỉ hiển thị các cơ sở dữ liệu đã xác thực mật khẩu thành công.
- Tự động bỏ qua bước chọn cơ sở dữ liệu và chuyển thẳng vào màn hình chính nếu người dùng chỉ thuộc về 1 database duy nhất.

### 1.3. Phân luồng Quyền hạn & Khám phá Model Động (Internal Employee vs Dynamic Portal Modules)
- **Người dùng nội bộ (`is_portal: false`)**: Cung cấp đầy đủ 5 tab điều hướng chính (Trang chủ, Tin nhắn, Chấm công, Phiếu hỗ trợ, Tài khoản):
  * **Tab Trang chủ (`Home`)**: Tích hợp các Widget quản trị nghiệp vụ thời gian thực: Thẻ Chấm công GPS & tiến độ ca làm việc (`hr_attendance`), Khối thống kê Quick Nav Grid (Ticket, Chat, Task), và Danh sách 3 công việc trọng tâm hôm nay (`project.task`).
  * **Tab Chấm công & Timesheet**: Độc quyền cho nhân viên nội bộ ghi nhận giờ công.
- **Người dùng đối tác/khách hàng (`is_portal: true`)**: Tuyệt đối chặn truy cập Tab Home và các module nội bộ. Áp dụng cơ chế cấp quyền theo Model cài đặt trên Tenant Database chuẩn Odoo 19:
  * Cài module nào ➔ Hiển thị phân hệ tính năng của module đó trên Mobile App.
  * Chưa cài module ➔ Tự động ẩn hoàn toàn phân hệ tương ứng khỏi giao diện Portal:
    - Module `helpdesk` (`helpdesk.ticket`): Hiển thị tab Phiếu hỗ trợ / Ticket. Nếu DB chưa cài ➔ Ẩn hoàn toàn tab Ticket.
    - Module `mail` (`discuss.channel`): Hiển thị tab Tin nhắn / Chat hỗ trợ.
    - Module `project` (`project.project`, `project.task`): Hiển thị danh mục Dự án/Công việc được chia sẻ cho Portal.
    - Module `base` (`res.users`, `res.partner`): Hiển thị tab Tài khoản (Tôi).
  * Tuyệt đối ẩn và chặn truy cập vào Trang chủ (`Home`), module Chấm công (`hr_attendance`) và Bảng chấm công (`hr_timesheet`).

#### Ma trận Phân hệ Ứng dụng & Model Odoo tương ứng
| Phân hệ / Màn hình trên App | Module Odoo | Model Odoo tương ứng | Quyền Nhân viên Nội bộ (`share=False`) | Quyền Khách hàng Portal (`share=True`) | Hành vi khi Tenant chưa cài Module |
|---|---|---|---|---|---|
| **Trang chủ (`Home`) & Chấm công GPS** | `hr_attendance` | `hr.attendance`, `hr.employee` | **Có** (Thẻ GPS, check-in/out, ca làm, đếm giờ, pháo hoa) | **Ẩn hoàn toàn** (Cấm truy cập Home) | Nếu chưa cài: Ẩn widget chấm công trên Home |
| **Bảng chấm công (`Timesheet`)** | `hr_timesheet` | `account.analytic.line`, `project.task` | **Có** (Bấm giờ Timer, nhật ký công, log giờ) | **Ẩn hoàn toàn** (Không có tab này) | Nếu chưa cài: Ẩn tab Timesheet |
| **Phiếu hỗ trợ (`Ticket`)** | `helpdesk` | `helpdesk.ticket`, `helpdesk.team` | **Có** (Xem, phân công, đổi stage, đóng ticket) | **Có** (Chỉ xem và tạo ticket của mình) | **Nếu chưa cài: Ẩn hoàn toàn tab Ticket khỏi App** |
| **Trò chuyện (`Chat`)** | `mail` | `discuss.channel`, `mail.message` | **Có** (Kênh nội bộ, nhóm, gọi thoại RTC) | **Có** (Chỉ chat với nhân viên CSKH/kỹ thuật) | Module mặc định Odoo Core |
| **Dự án của tôi (`Project`)** | `project` | `project.project`, `project.task` | **Có** (Widget Home & Task hôm nay) | **Có** (Chỉ xem task được share portal) | Ẩn widget Task trên Home nếu chưa cấu hình |
| **Tài khoản cá nhân (`Tôi`)** | `base` | `res.users`, `res.partner` | **Có** (Đổi mật khẩu, avatar, thông tin) | **Có** (Đổi mật khẩu, avatar, thông tin) | Luôn hiển thị (Module lõi Odoo) |

### 1.4. Tự động Hủy Đăng ký Thiết bị & Thu hồi Push Token khi Đăng xuất
- Khi người dùng đăng xuất, ứng dụng tự động gửi yêu cầu tới `/api/v1/mobile/notifications/unregister`.
- Máy chủ Odoo hủy kích hoạt device token tương ứng, ngăn chặn tuyệt đối việc thiết bị cũ nhận thông báo của người dùng sau khi thoát tài khoản.

### 1.5. Tự động Đăng nhập lại & Duy trì Phiên làm việc (Session Persistence)
- Lưu trữ an toàn mã truy cập (Access Token) và Refresh Token trong vùng nhớ mã hóa phần cứng của thiết bị di động (`FlutterSecureStorage`).
- Tự động khôi phục phiên làm việc và làm mới token ngầm khi mở ứng dụng mà không yêu cầu người dùng nhập lại mật khẩu.

### 1.6. Xóa Trắng Bộ nhớ Đệm Nhạy cảm RAM (Zero-Leak Memory Cleansing)
- Khi thực hiện đổi tài khoản hoặc chọn database mới, ứng dụng tự động kích hoạt `clearTemporaryMemory()`.
- Xóa sạch dữ liệu token tạm thời, thông tin người dùng và các khóa giải mã trong bộ nhớ RAM, chống tấn công trích xuất bộ nhớ.

### 1.7. Hạn chế Phiên Đăng nhập & Khóa Tài khoản Khi Nhập Sai
- Tích hợp cơ chế Rate-limiting tại backend Odoo để kiểm soát tần suất gửi yêu cầu đăng nhập.
- Khóa tạm thời hoặc áp dụng thời gian chờ tăng dần khi phát hiện hành vi dò mật khẩu brute-force.

### 1.8. Thay đổi Mật khẩu & Bảo vệ Tài khoản Người dùng
- Cung cấp luồng đổi mật khẩu trực tiếp trong ứng dụng, yêu cầu xác nhận mật khẩu hiện tại trước khi thiết lập mật khẩu mới.
- Tự động hủy toàn bộ các phiên làm việc đang hoạt động khác trên các thiết bị khác sau khi đổi mật khẩu thành công.

---

## ⏱️ PHÂN HỆ 2: QUẢN LÝ THỜI GIAN & CHẤM CÔNG (12 TÍNH NĂNG)

### 2.1. Chấm công Định vị Vệ tinh GPS & Hàng rào Địa lý (Geofencing)
- Thu nhận tọa độ địa lý kinh độ/vĩ độ qua GPS thiết bị với độ chính xác cao.
- Đối soát tự động khoảng cách giữa vị trí thực tế của nhân viên và tọa độ văn phòng công ty đã cấu hình trên Odoo.
- Chỉ cho phép ghi nhận Check-in / Check-out khi nhân viên nằm trong bán kính cho phép, ngăn chặn gian lận vị trí.

### 2.2. Ghi nhận Nhật ký Giờ làm Chuẩn Odoo (`account.analytic.line`)
- Ghi nhận chi tiết thời gian làm việc trực tiếp vào phân hệ Odoo Timesheet (`account.analytic.line`).
- Tự động liên kết bản ghi giờ làm với Dự án (`project_id`), Công việc (`task_id`), và Nhân viên (`employee_id`).

### 2.3. Đồng hồ Bấm giờ Công việc Thời gian thực (Stopwatch Work Timer)
- Đồng hồ đếm thời gian thực hiện công việc chính xác đến từng giây.
- Cho phép Bắt đầu, Tạm dừng, Tiếp tục và Đặt lại bộ đếm giờ một cách trực quan.
- Tự động duy trì trạng thái đếm giờ khi ứng dụng chuyển xuống chạy nền hoặc chuyển màn hình.

### 2.4. Tự động Phân luồng Ghi nhận Task Cá nhân
- Xử lý thông minh đối với các nhiệm vụ cá nhân không gắn mã dự án (`project_id == null`).
- Tự động chuyển hướng nội dung hoàn thành và thời gian vào Odoo Chatter (`mail.message`), ngăn chặn lỗi ràng buộc bắt buộc dự án của Odoo.

### 2.5. Bộ lọc Nhật ký Thời gian Thông minh theo Ngày, Tuần, Tháng & Dự án
- Cung cấp thanh lọc linh hoạt theo các mốc thời gian: Hôm nay, Tuần này, Tháng này và Tùy chọn khoảng thời gian.
- Lọc nhanh các bản ghi thời gian theo từng dự án cụ thể mà nhân viên đang tham gia.

### 2.6. Phân trang Động Chống Tải Lặp (Pagination Engine)
- Tải danh sách nhật ký công việc theo cơ chế phân trang động (Pagination & Infinite Scroll).
- Cơ chế khử trùng lặp dữ liệu (Deduplication) đảm bảo không xuất hiện các bản ghi ảo khi cuộn danh sách.

### 2.7. Bảng Tổng hợp Công & Thống kê Tỷ lệ Chuyên cần Tháng
- Thẻ chỉ số tổng hợp hiển thị trực quan tổng số ngày công đã đạt được trong tháng so với chỉ tiêu chuẩn (ví dụ: 21.5 / 26 công).
- Tính toán tỷ lệ phần trăm chuyên cần và tổng thời lượng làm việc tích lũy trong tháng.

### 2.8. Quản lý Ca làm việc & Nhận diện Vào Ca / Ra Ca
- Nhận diện trạng thái ca làm việc hiện tại của nhân sự (Ca sáng, Ca chiều, Ngoài giờ).
- Hiển thị nhãn trạng thái trực quan: "Đang làm việc" kèm thời gian làm việc lũy kế trong ngày.

### 2.9. Chỉnh sửa & Xóa Dòng Ghi nhận Nhật ký Giờ làm việc
- Cho phép nhân viên điều chỉnh mô tả công việc hoặc số giờ đã log trước khi kỳ chốt công diễn ra.
- Hỗ trợ xóa dòng nhật ký thời gian ghi nhầm kèm hộp thoại xác nhận an toàn.

### 2.10. Tự động Chuyển đổi Trạng thái Nhiệm vụ khi Hoàn tất Ghi giờ
- Tùy chọn đánh dấu công việc đã hoàn thành ngay khi dừng đồng hồ bấm giờ hoặc lưu nhật ký thời gian.
- Tự động kích hoạt chuyển trạng thái task trên Odoo sang Done/Completed.

### 2.11. Cảnh báo Giới hạn Giờ làm Tối đa trong Ngày & Tuần
- Kiểm tra hợp lệ thời lượng ghi nhận nhằm ngăn ngừa sai sót nhập liệu (ví dụ: nhập quá 24 giờ trong 1 ngày).
- Đưa ra cảnh báo thân thiện nhắc nhở người dùng kiểm tra lại thông tin trước khi gửi lên máy chủ.

### 2.12. Xuất Báo cáo & Bảng Tổng kết Nhật ký Thời gian
- Tổng hợp báo cáo thời lượng công việc theo từng dự án phục vụ công tác quyết toán và đối soát hiệu suất cá nhân.

---

## 💬 PHÂN HỆ 3: GIAO TIẾP NỘI BỘ & HỘI THOẠI ĐA PHƯƠNG TIỆN (27 TÍNH NĂNG)

### 3.1. Hệ thống Lọc Kênh Trò chuyện Thông minh 6 Nhóm
- Phân loại danh sách kênh thành 6 danh mục chuyên biệt: Tất cả, Chưa đọc, Trực tiếp (1-1), Nhóm nội bộ, Kênh thông tin, và Khách hàng Zalo OA.
- Cập nhật số lượng huy hiệu chưa đọc tức thời trên từng tab bộ lọc.

### 3.2. Heuristic Phân lập Kênh Zalo OA & Chăm sóc Khách hàng
- Thuật toán thông minh tự động nhận diện các kênh tích hợp Zalo OA, kênh dồn hỗ trợ hoặc kênh có tài khoản bot chăm sóc khách hàng.
- Tách biệt hoàn toàn luồng tin nhắn khách hàng Zalo ra khỏi danh mục Nhóm nội bộ công ty.

### 3.3. Khử Ký tự Thừa & Làm Sạch Tên Kênh Tự động
- Tự động bóc tách các tiền tố kỹ thuật hệ thống Odoo như `Users + Internal /`, `Users /` để hiển thị tên đối tác hoặc tên nhóm nguyên bản, trong sáng.

### 3.4. Quản lý Thành viên Nhóm Trò chuyện
- Bổ sung thành viên mới vào nhóm trò chuyện qua danh bạ nhân sự.
- Xóa thành viên khỏi nhóm và đồng bộ danh sách thành viên tức thời qua Odoo Discuss backend.

### 3.5. Rời Nhóm Trò chuyện & Phân định với Cuộc trò chuyện Cá nhân
- Cho phép thành viên tự rời khỏi nhóm trò chuyện với hộp thoại xác nhận.
- Ẩn hoàn toàn tùy chọn rời nhóm tại các cuộc trò chuyện trực tiếp 1-1, thay thế bằng tính năng Ẩn/Lưu trữ cuộc trò chuyện phù hợp nghiệp vụ.

### 3.6. Chia sẻ Liên kết Cuộc trò chuyện & Điều hướng Thông minh (Deep Linking)
- Tạo liên kết chia sẻ nhóm trò chuyện bảo mật theo định dạng chuẩn `/chat/<channel_id>/<uuid>`.
- Cơ chế chuyển hướng thông minh HTTP 303: Tự động đưa người dùng chưa đăng nhập về trang đăng nhập và chuyển tiếp thẳng vào phòng chat ngay sau khi xác thực thành công.

### 3.7. Cơ chế Sinh Mã Định danh Kênh An toàn (Non-locking UUID Generation)
- Loại bỏ hoàn toàn side-effect ghi vào cơ sở dữ liệu khi gọi các API đọc thông tin kênh (GET `/channels`, GET `/info`), xóa bỏ nguy cơ khóa hàng dữ liệu (Row Lock) trên bảng `discuss_channel`.
- Tự động cấp phát UUID v4 an toàn khi khởi tạo kênh mới (`create()`) hoặc qua action POST chủ động.

### 3.8. Đổi Tên Nhóm Toàn cục & Đặt Biệt danh Cá nhân hóa Cuộc trò chuyện 1-1
- Trưởng nhóm có quyền đổi tên nhóm trò chuyện đồng bộ toàn hệ thống.
- Người dùng có thể đặt Biệt danh (Nickname) riêng cho người trò chuyện 1-1, lưu trữ cục bộ bảo mật trên thiết bị mà không làm biến đổi tên gốc trên danh bạ ERP.

### 3.9. Tìm kiếm Nội dung Tin nhắn Trong Phòng trò chuyện (Capsule Search Bar)
- Thanh tìm kiếm tin nhắn dạng Capsule hiện đại, tích hợp nút xóa nhanh, bộ đếm số lượng kết quả trùng khớp `[X / Y]`.
- Tô màu nổi bật từ khóa tìm kiếm (Keyword Highlighting) trên từng dòng tin nhắn; tự động cuộn đến vị trí tin nhắn tương ứng.

### 3.10. Tìm kiếm Danh bạ & Kênh Trò chuyện Hỗ trợ Tiếng Việt Không Dấu
- Công cụ tìm kiếm tích hợp thuật toán bóc tách dấu thanh tiếng Việt, cho phép tìm kiếm nhanh tên đồng nghiệp hoặc tên nhóm mà không phụ thuộc vào cách gõ dấu.

### 3.11. Gọi Thoại Nội bộ WebRTC Âm thanh Chất lượng cao (P2P Audio Call)
- Thực hiện cuộc gọi thoại trực tiếp giữa 2 nhân sự thông qua giao thức WebRTC với codec âm thanh Opus băng thông rộng.
- Hỗ trợ đầy đủ các thao tác bật/tắt micro, chuyển đổi loa trong/loa ngoài, đếm thời lượng cuộc gọi.

### 3.12. Tích hợp Máy chủ Chuyển tiếp TURN Server & Dự phòng STUN Đa tầng
- Cung cấp cấu hình dynamic ICE Servers qua API backend `/api/v1/mobile/chat/call/config`.
- Tích hợp máy chủ Coturn TURN (`turn:turn.vuahethong.net:3478`) chống tịt tiếng triệt để khi gọi qua mạng 4G/5G hoặc mạng doanh nghiệp có Symmetric NAT.

### 3.13. Quản lý Cuộc gọi Nền Android 14+ qua Foreground Service Microphone
- Khai báo và kích hoạt dịch vụ nền `FOREGROUND_SERVICE_MICROPHONE` chuẩn mực theo yêu cầu của Android 14 (API 34+).
- Duy trì luồng thu âm micro ổn định, không bị hệ điều hành tắt khi nhân viên ẩn ứng dụng hoặc tắt màn hình trong lúc đàm thoại.

### 3.14. Cơ chế Heartbeat Phát hiện Mất mạng & Khôi phục Kết nối WebRTC
- Tự động giám sát trạng thái kết nối ICE; thiết lập khoảng thời gian chờ (Grace Period) 10 giây khi mạng bị ngắt quãng để thực hiện ICE Restart.
- Tự động ngắt cuộc gọi an toàn, giải phóng tài nguyên phần cứng và thông báo rõ ràng cho người dùng nếu mất kết nối quá thời gian chờ.

### 3.15. Tín hiệu Báo Bận Tự động (Fast-Busy Signal)
- Khi đang trong cuộc đàm thoại mà có cuộc gọi thứ ba gọi đến, ứng dụng tự động phản hồi tín hiệu máy bận (`reason: 'busy'`) về máy chủ.
- Giữ nguyên vẹn cuộc gọi hiện tại không bị gián đoạn, thông báo cho người gọi thứ ba trạng thái bận và kết thúc sau 1.2 giây.

### 3.16. Tích hợp Giao diện Cuộc gọi Hệ thống Native CallKit
- Kết nối với hệ thống gọi điện native của hệ điều hành di động (CallKit trên iOS và ConnectionService trên Android).
- Cho phép nhận và trả lời cuộc gọi ngay từ màn hình khóa của điện thoại.

### 3.17. Gửi Tin nhắn Đa Phương tiện
- Hỗ trợ gửi tin nhắn văn bản, hình ảnh, tài liệu tệp tin, đoạn ghi âm và video ngắn với tốc độ cao.
- Nén ảnh thông minh trước khi tải lên nhằm tối ưu băng thông di động.

### 3.18. Bộ chọn Tệp Đính kèm Đa Tầng Fallback (SAF Fallback)
- Cơ chế lựa chọn tệp đa tầng xử lý an toàn quyền truy cập bộ nhớ trên các phiên bản Android đời mới (Scoped Storage).
- Tự động chuyển đổi các chế độ chọn tệp khi gặp sự cố không tương thích của trình quản lý tệp trên thiết bị.

### 3.19. Trình Xem Ảnh Tương tác Đa điểm Trực tiếp In-App
- Mở và xem hình ảnh với đầy đủ tính năng: Thu phóng đa điểm (Pinch-to-zoom), kéo di chuyển (Pan), xoay ảnh 90° liên tục theo chu kỳ, chia sẻ ảnh qua System Share Sheet ra ứng dụng ngoài, và vuốt xuống để đóng.
- Tự động reset ma trận zoom và góc xoay khi lướt chuyển đổi ảnh trong PageView.
- Tải ảnh chất lượng cao kèm cơ chế đệm bộ nhớ mượt mà.

### 3.20. Mở & Xem Tệp Tài liệu Định dạng PDF, Excel, Word Trực tiếp In-App
- Tích hợp bộ giải mã xem trực tiếp các tệp văn phòng phổ biến ngay trong ứng dụng mà không cần chuyển hướng sang trình duyệt bên ngoài.

### 3.21. Tải & Lưu Ảnh và Video vào Thư viện Native của Thiết bị (Photos Album / Gallery)
- Tải ảnh và video từ cuộc trò chuyện / trình phát video in-app và lưu trực tiếp vào Thư viện hệ thống (Photo Gallery/Album/MediaStore) của máy với 1 chạm.

### 3.22. Tạo Bình chọn Khảo sát Ý kiến Thời gian thực (Poll Voting)
- Cho phép tạo các cuộc thăm dò ý kiến trong nhóm với nhiều lựa chọn.
- Cập nhật tỷ lệ phần trăm bình chọn của các thành viên theo thời gian thực.

### 3.23. Thả Cảm xúc Tin nhắn & Bảng Danh sách Chi tiết
- Thả biểu tượng cảm xúc (Reactions) nhanh vào từng tin nhắn.
- Chạm vào huy hiệu cảm xúc để mở bảng danh sách hiển thị chi tiết ảnh đại diện và họ tên những người đã thả reaction.

### 3.24. Đồng bộ Tin nhắn Thời gian thực qua WebSocket Odoo Bus
- Kết nối thường trực với dịch vụ thông điệp thời gian thực của Odoo (`bus.bus` WebSocket / Long-polling).
- Đẩy và nhận tin nhắn mới tức thời với độ trễ dưới 200ms.

### 3.25. Hệ thống Thông báo Đẩy Ưu tiên Cao (Heads-up Notification Banner)
- Cấu hình kênh thông báo Android với mức ưu tiên cao nhất (`Importance.max`), hiển thị banner thông báo nổi khi có tin nhắn mới.
- Hỗ trợ thông báo đánh thức (Wake-up) khi có cuộc gọi đến.

### 3.26. Đánh dấu Đã đọc Tin nhắn & Đếm Số lượng Chưa đọc Tự động
- Tự động đồng bộ trạng thái đọc tin nhắn lên máy chủ Odoo khi người dùng mở phòng trò chuyện.
- Xóa huy hiệu số tin chưa đọc tức thời trên danh sách hội thoại.

### 3.27. Sắp Xếp Dòng Thời Gian Tin Nhắn Chuẩn Xác & Trích Dẫn Trả Lời Sạch (Message Sorting & Clean Reply — BUG-024)
- Thiết lập tính bất biến sắp xếp giảm dần theo thời gian (`createdAt desc`) và ID trong danh sách tin nhắn ngược (`ListView(reverse: true)`), triệt tiêu hoàn toàn hiện tượng nhảy xáo trộn ngày khi làm mới hoặc tải thêm tin nhắn.
- Tích hợp chuẩn kiến trúc trích dẫn Odoo Discuss qua `parent_id` Many2one, loại bỏ triệt để mã HTML thô trên Odoo Web và bọc an toàn `Markup()` trên Backend Odoo.
- Chuẩn hóa thông minh các tệp ảnh, video, âm thanh đính kèm khi reply thành các nhãn tiếng Việt `[Hình ảnh]`, `[Video]`, `[Tin nhắn thoại]`.

### 3.28. Tắt Chuông Thông Báo Hội Thoại Linh Hoạt & Đồng Bộ Thời Gian Thực (Mute Notification & Real-Time Sync)
- Cung cấp BottomSheet chọn thời hạn tắt thông báo linh hoạt theo 4 mốc: Trong 1 giờ (`60m`), Trong 8 giờ (`480m`), Trong 24 giờ (`1440m`) và Cho đến khi tôi bật lại (`-1`), đồng bộ API Backend `/api/v1/mobile/chat/channels/<id>/mute`.
- Hiển thị biểu tượng chuông tắt thông báo `LucideIcons.bellOff` trên cả Danh sách kênh (`ChatV2ListScreen`) lẫn thanh Header phòng trò chuyện (`ChatV2DetailScreen`).
- Lắng nghe và đồng bộ hai chiều thời gian thực qua WebSocket Odoo Bus (`discuss.channel.member/mute`, `mail.channel.member/mute`, và `mail.record/insert`), tự động cập nhật trạng thái UI tức thì không cần reload hay kéo làm mới.

---

## 📊 PHÂN HỆ 4: QUẢN LÝ CÔNG VIỆC & BẢNG ĐIỀU KHIỂN (9 TÍNH NĂNG)

### 4.1. Bảng Điều khiển Kép Thời gian thực (Dual-Tier Metric Cards)
- Hiển thị 4 thẻ chỉ số tổng quan tại trang chủ: Số giờ làm trong ngày, Trạng thái chấm công, Số lượng công việc cần làm, và Số lượng phiếu hỗ trợ đang xử lý.
- Dữ liệu nạp tập trung từ API `/api/v1/mobile/dashboard/summary`.

### 4.2. Lời chào Thông minh Cá nhân hóa Theo Buổi & Nạp Thông tin Định danh ERP
- Tiêu đề trang chủ tự động thay đổi lời chào thân thiện theo mốc thời gian trong ngày (Chào buổi sáng, Buổi chiều, Buổi tối).
- Hiển thị đầy đủ Họ tên, Chức vụ chuyên môn và Tên công ty/chi nhánh của nhân sự từ dữ liệu ERP.

### 4.3. Hiệu ứng Pháo hoa Chúc mừng Khi Hoàn thành Chấm công
- Hiển thị hiệu ứng đồ họa pháo hoa chúc mừng trực quan ngay sau khi nhân viên thực hiện thao tác Check-in thành công tại trang chủ, mang lại trải nghiệm hào hứng khi bắt đầu ngày làm việc.

### 4.4. Tạo Công việc Mới & Phân bổ Dự án Động từ Odoo
- Cung cấp form tạo nhiệm vụ nhanh với danh mục dự án được nạp động từ phân hệ `project.project` của Odoo.
- Ràng buộc dữ liệu chuẩn chỉ ngăn chặn các lỗi bất nhất dự án và nhiệm vụ.

### 4.5. Giao việc & Phân quyền Nhiều Người Phụ trách (Many2many `user_ids`)
- Hỗ trợ phân công nhiệm vụ cho nhiều nhân sự cùng phụ trách thông qua cấu trúc quan hệ Many2many chuẩn Odoo ORM.
- Tự động thiết lập quyền theo dõi để nhân viên được phân công luôn nhìn thấy công việc trong danh sách của mình.

### 4.6. Trình Biên tập Checklist Đầu việc Phụ (Subtasks Checklist Editor)
- Cho phép tạo danh sách các đầu việc con (Checklist items) trong từng công việc.
- Đánh dấu hoàn thành từng mục kèm hiệu ứng gạch ngang và tự động tính toán thanh tiến độ phần trăm hoàn thành của nhiệm vụ.

### 4.7. Hoàn tất Nhanh Công việc & Ghi nhận Số giờ Thực hiện
- Hộp thoại hoàn thành công việc nhanh 1 chạm, cho phép ghi nhận tổng thời gian đã thực hiện và đóng nhiệm vụ mà không cần trải qua nhiều bước rườm rà.

### 4.8. Trung tâm Thông báo Hoạt động & Quản lý Lịch sử Thông báo
- Màn hình quản lý toàn bộ các thông báo về công việc, chấm công và tin nhắn hệ thống.
- Hỗ trợ vuốt để xóa từng thông báo hoặc xóa toàn bộ lịch sử thông báo.

### 4.9. Tăng tốc Nạp Dữ liệu Dưới 100ms với Kiến trúc Đệm SWR
- Ứng dụng mô hình đệm dữ liệu Stale-While-Revalidate: Hiển thị ngay lập tức dữ liệu được lưu trong bộ nhớ đệm RAM và đồng thời gửi yêu cầu cập nhật ngầm từ máy chủ, loại bỏ thời gian chờ màn hình trắng.

---

## 🎫 PHÂN HỆ 5: HỖ TRỢ KỸ THUẬT & PHIẾU DỊCH VỤ (14 TÍNH NĂNG)

### 5.1. Danh sách Phiếu Hỗ trợ Phân loại Theo Trạng thái
- Phân nhóm phiếu hỗ trợ rõ ràng thành 2 tab: "Đang xử lý" và "Hoàn thành" kèm số lượng thống kê trên từng tab.

### 5.2. Tìm kiếm & Lọc Phiếu Yêu cầu
- Công cụ tìm kiếm tức thời theo mã số phiếu, tiêu đề yêu cầu, tên khách hàng hoặc nhân viên kỹ thuật phụ trách.

### 5.3. Xem Chi tiết Phiếu Hỗ trợ với Giao diện Trượt Chuyển cảnh Native
- Chuyển tiếp mượt mà từ danh sách vào màn hình chi tiết phiếu với hiệu ứng chuyển cảnh phẳng native, loại bỏ hiện tượng giật cục giao diện.

### 5.4. Hiển thị Đầy đủ Khách hàng Doanh nghiệp, Người Liên hệ & Nhân viên Phụ trách
- Cung cấp đầy đủ thông tin: Tên công ty khách hàng (`partner_name`), Người đại diện gửi yêu cầu, và Nhân viên kỹ thuật đang trực tiếp xử lý phiếu.

### 5.5. Trao đổi & Bình luận Hai chiều Trực tiếp Đồng bộ Odoo Chatter
- Khung trao đổi kỹ thuật trên từng phiếu, đồng bộ tin nhắn hai chiều trực tiếp với luồng Chatter của Odoo Helpdesk.

### 5.6. Làm sạch Định dạng HTML và Hiển thị Văn bản Thuần Chuẩn xác
- Bộ lọc tự động phân tích và loại bỏ các thẻ HTML phức tạp trong mô tả phiếu hoặc email phản hồi của khách hàng, hiển thị văn bản rõ ràng, dễ đọc trên di động.

### 5.7. Đo lường Thời hạn Cam kết Dịch vụ (SLA Status & Deadline Indicator)
- Theo dõi hạn chót cam kết chất lượng dịch vụ (SLA Deadline).
- Hiển thị trực quan trạng thái trong hạn hoặc quá hạn với màu sắc cảnh báo rõ ràng.

### 5.8. Tạo Phiếu Yêu cầu Mới Kèm Đính kèm Tệp Tài liệu và Hình ảnh
- Cho phép tạo mới phiếu hỗ trợ với đầy đủ tiêu đề, phân loại độ ưu tiên, mô tả sự vụ và đính kèm nhiều ảnh chụp sự cố hoặc tài liệu liên quan.

### 5.9. Quản lý Vòng đời Phiếu: Nhận phiếu, Chuyển tiếp Giai đoạn, Đóng phiếu
- Kỹ thuật viên có thể bấm "Nhận phiếu" để tự gán việc cho mình, cập nhật tiến độ xử lý và đánh dấu hoàn thành khi giải quyết xong yêu cầu.

### 5.10. Mở lại Phiếu Đã Hoàn thành (Reopen Ticket Workflow)
- Nút "Mở lại phiếu" trực quan trên các phiếu thuộc tab Hoàn thành, cho phép kích hoạt lại quy trình xử lý khi khách hàng có yêu cầu bổ sung.

### 5.11. Trình Xem Tệp Đính kèm Đa Định dạng In-App Kèm Xác thực Bearer Token
- Mở tệp ảnh, tệp PDF trực tiếp trong ứng dụng; tự động đính kèm mã xác thực Token trong yêu cầu tải tệp, ngăn ngừa lỗi bị chuyển hướng về màn hình đăng nhập Odoo Web.

### 5.12. Hiển thị Thumbnail Ảnh Xem trước Thu nhỏ và Định dạng Tên Tệp Thông minh
- Thẻ đính kèm hiển thị hình ảnh thu nhỏ thực tế của tệp đính kèm.
- Tự động chuẩn hóa hiển thị các tên tệp chụp màn hình chung chung thành tiêu đề thân thiện kèm dung lượng tệp chuẩn xác.

### 5.13. Tải Xuống & Lưu Tệp Đính kèm vào Bộ nhớ Thiết bị An toàn
- Tải tệp tin về thư mục Downloads/Documents của thiết bị với tên tệp được gắn mã định danh chống ghi đè tệp cũ.

### 5.14. Cơ chế Phân tách Dữ liệu Bảo mật Đa Tenant Khách hàng
- Áp dụng cơ chế kiểm soát truy cập nghiêm ngặt tại backend Odoo: Tài khoản khách hàng Portal chỉ được phép truy xuất đúng các phiếu thuộc về tổ chức của mình, ngăn chặn tuyệt đối lỗ hổng rò rỉ dữ liệu chéo (IDOR).

---

## 👤 PHÂN HỆ 6: HỒ SƠ CÁ NHÂN & TIỆN ÍCH HỆ THỐNG (9 TÍNH NĂNG)

### 6.1. Thẻ Định danh Nhân sự Hero Profile Card
- Hiển thị thông tin cá nhân nổi bật: Ảnh đại diện lớn, Họ tên, Chức vụ công tác, Địa chỉ email công vụ và Đơn vị trực thuộc được đồng bộ từ hồ sơ nhân sự Odoo.

### 6.2. Cập nhật & Thay đổi Ảnh Đại diện Cá nhân
- Hỗ trợ đổi ảnh đại diện cá nhân trực tiếp từ camera chụp mới hoặc chọn từ thư viện ảnh của máy điện thoại, tự động tối ưu hóa và đồng bộ lên server.

### 6.3. Quản lý Giao diện Sáng / Tối (Dark / Light Theme Controller)
- Cung cấp 3 chế độ hiển thị: Giao diện Tối (Refined Tech Luxury Slate 900), Giao diện Sáng trang nhã, hoặc Tự động chuyển đổi theo thiết lập của hệ điều hành.

### 6.4. Dọn dẹp Bộ nhớ Đệm Ứng dụng An toàn (Application Cache Cleaner)
- Công cụ tính toán dung lượng bộ nhớ tạm và giải phóng bộ nhớ đệm an toàn chỉ với một chạm, giúp ứng dụng luôn hoạt động nhẹ nhàng, mượt mà.

### 6.5. Quản lý Mã Định danh Thiết bị Phục vụ Nhận Thông báo (FCM Token)
- Tự động đăng ký và quản lý chu kỳ sống của Firebase Cloud Messaging Token trên máy chủ để đảm bảo nhận thông báo kịp thời.

### 6.6. Màn hình Thông tin Ứng dụng, Giấy phép & Chính sách Quyền Riêng tư
- Cung cấp số hiệu phiên bản ứng dụng, bản quyền phần mềm 360 CORP và liên kết xem Chính sách quyền riêng tư của hệ thống.

### 6.7. Bảng Giới thiệu Tính năng Mới Theo Phiên bản (What's New Sheet)
- Bảng giới thiệu ngắn gọn các nâng cấp và tính năng nổi bật được bổ sung trong bản dựng mới nhất để người dùng dễ dàng nắm bắt.

### 6.8. Cơ chế Đăng xuất Bảo mật & Xóa Trắng Dữ liệu 4 Tầng Toàn diện
- Quy trình đăng xuất bảo mật toàn diện: Thu hồi token trên server, xóa sạch dữ liệu đệm RAM của 10 phân hệ, xóa an toàn vùng nhớ máy và đưa trạng thái ứng dụng về ban đầu.

### 6.9. Thu hồi & Xóa Tài khoản Khỏi Thiết bị (Account Deletion & Data Wipe)
- Cho phép người dùng xóa hoàn toàn thông tin định danh của tài khoản khỏi thiết bị di động, đảm bảo an toàn tuyệt đối khi chuyển giao hoặc nâng cấp điện thoại.
