# Kịch Bản Kiểm Thử E2E Livechat Omnichannel: Web Widget ⟷ Odoo Discuss ⟷ VCloud Mobile App

> **Mã tài liệu**: `docs/guides/KICH_BAN_TEST_OMNICHANNEL_LIVECHAT.md`  
> **Phiên bản chuẩn hóa**: AIaC v3.8 / VCloud 2026  
> **Mục tiêu**: Hướng dẫn chi tiết từng bước kiểm thử luồng hội thoại đa kênh xuyên suốt:  
> Khách chat trên Web Widget ➔ Nhân viên Sale/Admin phản hồi trên Odoo Web ➔ Kiểm tra 2 phòng trực "Looking for help" trên Odoo Discuss ➔ Khách đăng nhập VCloud Mobile kiểm tra kế thừa lịch sử chat cũ.

---

## 1. BẢNG THÔNG TIN MÔI TRƯỜNG & TÀI KHOẢN KIỂM THỬ

| Vai trò kiểm thử | Nền tảng / Ứng dụng | Đường dẫn truy cập (URL) | Tài khoản (`login` / `password`) | Ghi chú |
|---|---|---|---|---|
| **1. Khách Hàng (Web Widget)** | Trình duyệt Web (Tab Ẩn danh / Incognito) | • `http://192.168.1.100:1900/im_livechat/support/3?db=vcloud_test_v19` (Customer Care)<br>• `http://192.168.1.100:1900/im_livechat/support/2?db=vcloud_test_v19` (Technical Support) | Khách vãng lai (hoặc Portal Cookie) | Mở giao diện Livechat Widget chuẩn Odoo |
| **2. Nhân Viên Trực Ca (Operator)** | Odoo 19 Web Backend | `http://192.168.1.100:1900/web` | **`admin`** / `admin` (hoặc `sale` / `123`) | Database: **`vcloud_test_v19`** |
| **3. Điều Phối / Quản Lý Ca** | Odoo 19 Discuss | `http://192.168.1.100:1900/web#action=mail.action_discuss` | **`admin`** / `admin` | Kiểm tra 2 phòng trực **"Looking for help"** |
| **4. Khách Hàng (Mobile App)** | VCloud Flutter Web / App | `http://localhost:8089/#/chat` | **`portal`** / `portal` (hoặc `khachhangmoi`) | Database: **`vcloud_test_v19`** |

---

## 2. QUY TRÌNH KIỂM THỬ 5 BƯỚC CHI TIẾT (STEP-BY-STEP)

```text
[BƯỚC 0: Kiểm Tra Điều Kiện Tiên Quyết (Precondition)]
       │  (Docker running, DB ready, Operator assigned)
       ▼
[BƯỚC 1: Khách Chat Web Widget] 
       │  (Gửi: "Xin chào 360 CORP, tôi cần tư vấn...")
       ▼
[BƯỚC 2: Operator Nhắn Qua Lại Trên Odoo Web]
       │  (Nhân viên phản hồi ➔ Khách nhận được tức thì)
       ▼
[BƯỚC 3: Kiểm Tra Odoo Discuss "Looking for help"]
       │  (Đối soát phiên trực Customer Care / Tech Support, lệnh :lead/:ticket)
       ▼
[BƯỚC 4: Khách Vào VCloud Mobile App Kiểm Tra]
          (Lịch sử chat cũ tự động đồng bộ sang App Mobile)
```

---

### BƯỚC 0: Kiểm Tra Điều Kiện Tiên Quyết (Precondition)

1. **Docker Container hoạt động**: SSH vào Local Server xác nhận container Odoo 19 đang chạy:
   ```bash
   ssh local "docker ps | grep odoo_dev_v19"
   ```
   Kết quả phải thấy container `odoo_dev_v19` có port `1900` đang `Up`.

2. **Database `vcloud_test_v19` sẵn sàng**: Truy cập `http://192.168.1.100:1900/web/database/selector`, xác nhận DB `vcloud_test_v19` có trong danh sách.

3. **Module đã cài đặt**: Đăng nhập `admin`/`admin` vào Odoo Web, vào `Settings → Technical → Installed Modules`, xác nhận:
   - `im_livechat` ✅ Installed
   - `v_mobile` ✅ Installed

4. **Operator đã được gán vào kênh Livechat**: Vào `Live Chat → Channels`, kiểm tra 2 kênh:
   - **Customer Care** (ID: 3): Tài khoản `admin` nằm trong danh sách `Operators`.
   - **Technical Support** (ID: 2): Tài khoản `admin` nằm trong danh sách `Operators`.
   > ⚠️ Nếu thiếu Operator, Widget sẽ hiện chấm xám (Offline) và không thể bắt đầu chat.

---

### BƯỚC 1: Khách Hàng Mở Web Widget & Bắt Đầu Chat Hỗ Trợ

1. Mở **Trình duyệt Web ở chế độ Ẩn danh (Incognito)** để tách biệt session với tài khoản nội bộ.
2. Truy cập vào URL phòng trực Livechat (kèm tham số `?db=vcloud_test_v19` để Odoo nhận đúng Database):
   - **Tư vấn CSKH / Bán hàng**: `http://192.168.1.100:1900/im_livechat/support/3?db=vcloud_test_v19`
   - *(Hoặc Hỗ trợ kỹ thuật)*: `http://192.168.1.100:1900/im_livechat/support/2?db=vcloud_test_v19`
3. Quan sát giao diện:
   - Xuất hiện cửa sổ Livechat chuẩn Odoo với lời chào:  
     *"Dạ em chào Quý khách! Em là Chuyên viên CSKH 360 CORP, em có thể hỗ trợ gì cho anh/chị ạ?"*
   - Chấm trạng thái 🟢 Online đang sáng (do có nhân viên `admin` đang trực).
4. Khách hàng gõ tin nhắn đầu tiên:
   - **Nội dung mẫu**: `Xin chào, tôi là khách hàng mới cần tư vấn phần mềm quản trị cho doanh nghiệp.`
   - Nhấn **Enter** gửi tin.

---

### BƯỚC 2: Nhân Viên (Sale / Admin) Tiếp Nhận Ca & Nhắn Tin Qua Lại

1. Mở một **cửa sổ trình duyệt thông thường** (khác với cửa sổ ẩn danh của khách).
2. Đăng nhập vào Odoo Web Backend:
   - URL: `http://192.168.1.100:1900/web/login`
   - Chọn Database: **`vcloud_test_v19`**
   - Tài khoản: **`admin`** / Mật khẩu: **`admin`** (hoặc `sale` / `123`).
3. Quan sát thanh thông báo trên cùng (Top Bar Odoo):
   - Icon tin nhắn / bong bóng chat có thông báo phiên Livechat mới.
   - Cửa sổ chat pop-up góc dưới bên phải mở ra phiên chat với khách.
4. Nhân viên trực ca trả lời khách:
   - **Nội dung mẫu**: `Dạ em chào anh/chị! Em là chuyên viên tư vấn 360 CORP. Anh/chị cho em xin tên và số điện thoại để em gửi báo giá chi tiết nhé ạ.`
   - Nhấn **Enter** gửi.
5. **Đối soát phản hồi thời gian thực**:
   - Quay lại cửa sổ ẩn danh của khách (Bước 1): Khách nhìn thấy tin nhắn phản hồi của nhân viên ngay lập tức.
   - Khách trả lời tiếp: `Số điện thoại của tôi là 0901234567, email: khachhang@gmail.com.`
   - Nhân viên trên Odoo nhận được đầy đủ nội dung.

---

### BƯỚC 3: Kiểm Tra Tại Odoo Discuss Ở 2 Phòng Trực "Looking for help"

1. Trên màn hình Odoo Web của nhân viên, mở module **Discuss (Thảo luận)**:
   - Truy cập URL: `http://192.168.1.100:1900/web#action=mail.action_discuss`
   - Hoặc click vào menu chính ➔ chọn app **Thảo luận (Discuss)**.
2. Quan sát thanh Menu bên trái (Sidebar):
   - Tìm mục **`Looking for help`** (hoặc mục **`Livechat`**).
   - Kiểm tra sự xuất hiện của 2 phòng trực chuẩn:
     * 🟢 **`Customer Care`** (ID: 3)
     * 🟢 **`Technical Support`** (ID: 2)
3. Bấm vào phiên chat vừa thực hiện với khách hàng:
   - **Lịch sử hội thoại**: Toàn bộ các tin nhắn trao đổi qua lại ở Bước 1 & Bước 2 hiển thị đầy đủ, không thiếu tin nào.
   - **Thông tin khách hàng**: Hiển thị IP, trang nguồn truy cập, thời gian bắt đầu ca chat.
4. *(Tùy chọn nâng cao — Odoo Core Quick Actions)*:
   - Nhân viên gõ lệnh nhanh vào khung chat Odoo Discuss:
     * Gõ: `/lead Tư vấn phần mềm quản trị cho khách hàng mới` ➔ Odoo Core tự động tạo một cơ hội bán hàng **`crm.lead`** kèm trích lục toàn bộ nội dung đoạn chat vào trường mô tả.
     * Hoặc gõ: `/ticket Khách hàng báo sự cố kết nối` ➔ Odoo Core tự động tạo một phiếu hỗ trợ **`helpdesk.ticket`**.

---

### BƯỚC 4: Đăng Nhập VCloud Mobile App — Kiểm Tra Kế Thừa Lịch Sử Chat Cũ (Omnichannel Continuity)

1. Mở ứng dụng VCloud Mobile:
   - Trên trình duyệt Web Mobile: `http://localhost:8089/#/chat`
   - *(Hoặc mở ứng dụng VCloud trên điện thoại / Simulator)*.
2. Đăng nhập bằng tài khoản Khách hàng Portal:
   - Database: **`vcloud_test_v19`**
   - Tài khoản: **`portal`** / Mật khẩu: **`portal`**
3. Vào tab **`Chat`** (biểu tượng bong bóng chat ở thanh điều hướng dưới):
   - **Kiểm tra Danh sách hội thoại (`ChatV2ListScreen`)**:
     * Kênh **`Customer Care`** (hoặc `Technical Support`) xuất hiện trong danh sách hội thoại.
     * Dòng phụ đề (subtitle) hiển thị đúng tin nhắn cuối cùng vừa trao đổi trên Web.
     * Bộ lọc filter chip: Thuộc nhóm chip **`[ Hỗ trợ 3 ]`**, không bị dồn nhầm vào Nhóm hay Zalo OA.
4. Bấm mở vào chi tiết phòng chat:
   - **Xác minh lịch sử tin nhắn**:
     * Đoạn chat trao đổi lúc nãy trên Web Live Chat Widget xuất hiện **nguyên vẹn 100%** trên App Mobile.
     * Tin nhắn của chuyên viên tư vấn hiển thị avatar đại diện và chức danh bảo mật (`Chuyên viên tư vấn`).
5. Thử nhắn tiếp một tin nhắn từ Mobile App:
   - **Nội dung mẫu**: `Tôi vừa đăng nhập vào App VCloud trên điện thoại, các bạn hỗ trợ tiếp ở đây nhé.`
   - Nhấn gửi trên Mobile.
6. **Đối soát hai chiều (Two-Way Sync)**:
   - Quay lại màn hình Odoo Discuss trên Web của nhân viên (Bước 3):
   - Nhân viên thấy tin nhắn mới từ Mobile App xuất hiện ngay lập tức trong cùng một luồng hội thoại.

---

## 3. BẢNG CHECKLIST NGHIỆM THU E2E (AUDIT CHECKLIST)

| STT | Hạng mục kiểm thử | Tiêu chuẩn Đạt (Acceptance Criteria) | Kết quả thực tế |
|:---:|---|---|:---:|
| 1 | **Hiển thị Web Widget** | Truy cập `/im_livechat/support/3`, hiển thị lời chào chuẩn và chấm 🟢 Online | ⬜ PENDING |
| 2 | **Khách gửi tin từ Widget** | Tin nhắn đi mượt mà, không bị lỗi CORS hay timeout | ⬜ PENDING |
| 3 | **Operator nhận thông báo** | Odoo Web Backend pop-up cửa sổ chat nhận ca trực tiếp | ⬜ PENDING |
| 4 | **Nhắn qua lại 2 chiều** | Khách trên Widget và Nhân viên trên Odoo nhận tin nhau tức thì (< 1 giây) | ⬜ PENDING |
| 5 | **Phòng trực "Looking for help"** | Phiên chat nằm đúng mục Looking for help trong Odoo Discuss | ⬜ PENDING |
| 6 | **Tách biệt 2 phòng ban** | Khách chọn Customer Care vào đúng phòng 3, Tech Support vào đúng phòng 2 | ⬜ PENDING |
| 7 | **Mobile App nạp lịch sử cũ** | Đăng nhập Portal trên App Mobile thấy toàn bộ tin nhắn đã chat trên Web | ⬜ PENDING |
| 8 | **Định danh hiển thị chuẩn** | Phía Mobile hiển thị tên phòng ban (`Customer Care`), không lộ tên Admin | ⬜ PENDING |
| 9 | **Nhắn tiếp tục từ Mobile** | Nhắn từ Mobile App, Odoo Discuss nhận được ngay trong cùng một thread | ⬜ PENDING |
| 10| **Bộ lọc chip trên Mobile** | Kênh Livechat được đếm chuẩn vào chip `Hỗ trợ`, ẩn các chip `(0)` | ⬜ PENDING |
| 11| **Lệnh nhanh `/lead` trong Discuss** | Gõ `/lead ...` trong phiên chat tạo được `crm.lead` kèm nội dung chat | ⬜ PENDING |
| 12| **Lệnh nhanh `/ticket` trong Discuss** | Gõ `/ticket ...` trong phiên chat tạo được `helpdesk.ticket` kèm nội dung | ⬜ PENDING |

---

## 4. HƯỚNG DẪN XỬ LÝ SỰ CỐ NHANH (TROUBLESHOOTING)

1. **Khách mở Web Widget thấy chấm xám (Offline)**:
   - *Nguyên nhân*: Chưa có tài khoản nhân viên nào trong danh sách `user_ids` của kênh đăng nhập Odoo.
   - *Khắc phục*: Đăng nhập tài khoản `admin` vào `http://192.168.1.100:1900` trên một tab trình duyệt để kích hoạt trạng thái online của ca trực.

2. **Mobile App chưa hiện tin nhắn cũ ngay khi vừa đăng nhập**:
   - *Khắc phục*: Vuốt nhẹ màn hình danh sách chat xuống để kích hoạt `RefreshIndicator` tải lại kênh mới nhất từ backend.

3. **CORS Error khi Flutter Web gọi API Odoo (`localhost:8089` → `192.168.1.100:1900`)**:
   - *Nguyên nhân*: Trình duyệt chặn cross-origin request giữa 2 domain/port khác nhau.
   - *Khắc phục*: Sử dụng script khởi chạy chuẩn có SSH tunnel:
     ```bash
     cd /media/tanma/DATA/save/mobile_versions/vclients && ./launch_web_ssh.sh 19
     ```
     Hoặc chạy Chrome với cờ `--disable-web-security`:
     ```bash
     flutter run -d chrome --web-port 8089 --web-browser-flag "--disable-web-security"
     ```

4. **Khách mở Web Widget bị lỗi 404 (Not Found)**:
   - *Nguyên nhân*: Môi trường Odoo Local Server có nhiều database (multi-DB). Trình duyệt Incognito chưa có cookie session nên Odoo không nhận diện được database mặc định.
   - *Khắc phục*: Luôn đính kèm tham số database vào URL:
     `http://192.168.1.100:1900/im_livechat/support/3?db=vcloud_test_v19`

5. **Lỗi 500: Internal Server Error khi truy cập `/web/signup`**:
   - *Hiện tượng*: Mở trang đăng ký tài khoản portal trên trình duyệt ẩn danh báo lỗi `500: Internal Server Error` (ValueError: Không thể định vị phần tử `//div[hasclass('field-name')]`).
   - *Nguyên nhân*: View kế thừa mồ côi `backend_base.signup_phone_field` (ID 8613) của module đã gỡ cài đặt trỏ nhầm `inherit_id` sang `auth_signup.fields` (ID 388 - vốn chỉ chứa password), khiến QWeb engine bị crash khi render.
   - *Khắc phục*: Đã xoá view mồ côi 8613, cấu hình lại template chuẩn `backend_ui.signup_phone_field` (ID 10030) kế thừa trực tiếp `auth_signup.signup` (ID 389) và khởi động lại container Odoo.

6. **Lỗi xác nhận form đăng ký bị từ chối (Báo thiếu Số điện thoại / Điều khoản)**:
   - *Hiện tượng*: Điền thông tin đăng ký bấm nút xác nhận bị báo lỗi *"Vui lòng nhập Số điện thoại liên hệ để hoàn tất đăng ký tài khoản"* hoặc *"Vui lòng đồng ý với Điều khoản dịch vụ và Chính sách bảo mật để tiếp tục"*, nhưng trên màn hình trước đó không có 2 ô này.
   - *Nguyên nhân*: Controller `BackendUIAuthSignupHome` (module `backend_ui`) kiểm tra validation bắt buộc `phone` và checkbox `accept_terms`, nhưng giao diện trước đó bị thiếu view hiển thị.
   - *Khắc phục*: View `backend_ui.signup_phone_field` đã được kích hoạt hoàn chỉnh, bổ sung trường nhập Số điện thoại (tự động chuẩn hóa định dạng `+84`) và checkbox đồng ý Điều khoản & Bảo mật. Sau khi tick chọn và nhập đầy đủ, tài khoản tạo thành công 100% và chuyển hướng trực tiếp vào phòng chat Livechat.

