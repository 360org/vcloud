# ĐẶC TẢ KỸ THUẬT: MENU ỨNG DỤNG ĐÁY & ĐIỀU HƯỚNG LAI GHÉP (BOTTOM APP DRAWER & HYBRID WEBVIEW)

> **Mã tính năng:** `FEAT-BOTTOM-APP-DRAWER-HYBRID`  
> **Dự án:** Vcloud Mobile (`vclients` - Flutter) & Backend Odoo (`v_mobile_17` / `v_mobile_19`)  
> **Tác giả:** Ma Nguyễn Nhật Tân (Developer)  
> **Ngày lập:** 2026-10-26  
> **Trạng thái:** ĐÃ HOÀN THÀNH & NGHIỆM THU (10/10 TEST CASES PASS)

---

## 1. Bối cảnh & Bài toán Kỹ thuật (Problem Statement)

### 1.1 Vấn đề hiện tại
- Hệ thống Odoo của doanh nghiệp có hơn 30 phân hệ nghiệp vụ (Kế toán, Tuyển dụng, Chuyên cần, Khảo sát, Chiến dịch, Quản lý Email, eLearning, AI Provider...).
- Hiện tại App Mobile Vcloud chỉ mới phát triển Native Flutter cho 4 module cốt lõi: **Trang chủ**, **Trò chuyện (Discuss/Chat)**, **Điểm danh & Timesheet**, và **Yêu cầu hỗ trợ (Ticket)**.
- Người dùng khi cần truy cập các phân hệ khác (Kế toán, Tuyển dụng, Khảo sát...) buộc phải thoát app và mở trình duyệt web ngoài, gây đứt gãy trải nghiệm làm việc di động.
- Nếu lập trình Native toàn bộ 30+ module trên Flutter thì chi phí và thời gian triển khai quá lớn (bất khả thi trong ngắn hạn).

### 1.2 Giải pháp Kiến trúc Lai Ghép (Hybrid Architecture Paradigm)
- **Menu Ứng dụng Đáy (Bottom App Drawer):** Thêm 1 icon "Ứng dụng" (icon lưới `LucideIcons.layoutGrid`) trên thanh điều hướng dưới đáy (Bottom Navigation Bar). Bấm vào sẽ trượt một Bottom Sheet từ dưới lên hiển thị lưới icon tất cả các ứng dụng Odoo (y hệt giao diện App Switcher Odoo Backend).
- **Bộ điều hướng Lai ghép Thông minh (Hybrid Router):**
  - **Module ĐÃ CÓ Native Flutter** (Chat, Timesheet, Ticket, Profile): Điều hướng mượt mà trong app Flutter (`context.pushNamed(...)`).
  - **Module CHƯA CÓ Native Flutter** (Kế toán, Tuyển dụng, Khảo sát, eLearning, AI Provider...): Tự động mở màn hình trình duyệt nhúng **In-App WebView**, tự động inject Cookie/Session Odoo để người dùng làm việc trực tiếp trên nền web Odoo mà không cần đăng nhập lại.

---

## 2. Kiến trúc Hệ thống & Luồng Dữ liệu (System Architecture)

### 2.1 Sơ đồ Phân quyền & Điều hướng
```text
                         [NGƯỜI DÙNG BẤM ICON "ỨNG DỤNG"]
                                        │
                                        ▼
                  [GỌI API: /api/v1/mobile/menu/apps]
                                        │
                                        ▼
                       [ODOO BACKEND ORM RESOLVER]
                   `ir.ui.menu`.load_menus() + res.groups
            (Lọc tự động 100% theo quyền hạn của tài khoản)
                                        │
                                        ▼
              [TRẢ VỀ DANH SÁCH MENU ĐƯỢC PHÉP CHO MOBILE]
              (ID, Name, Icon Data / SVG, Action ID, xmlid)
                                        │
                                        ▼
             [FLUTTER HIỂN THỊ BOTTOM SHEET DẠNG LƯỚI 4 CỘT]
             ┌──────────────────────────────────────────────┐
             │ [Bookmark] [All apps]                        │
             │ [Email] [AI] [DB] [Cloud]                    │
             │ [Mkt] [Chuyên cần] [Tuyển dụng] [Provider]   │
             │ [Hỗ trợ] [Commissions] [Chiến dịch] [Kế toán]│
             │ ...                                          │
             │ TIỆN ÍCH HỆ THỐNG: Hướng dẫn / Support / Cài đặt│
             └──────────────────────┬───────────────────────┘
                                    │ Bấm chọn 1 Ứng dụng
                                    ▼
                     [KIỂM TRA BẢNG ĐỊNH TUYẾN NATIVE]
                                    │
                  ┌─────────────────┴─────────────────┐
                  ▼                                   ▼
          [ĐÃ CÓ TRONG FLUTTER]             [CHƯA CÓ TRONG FLUTTER]
          - Chat (/chat)                    - Kế toán (/web#action=...)
          - Timesheet (/timesheet)          - Tuyển dụng (/web#action=...)
          - Ticket (/tickets)               - Khảo sát (/web#action=...)
          - Profile (/profile)              - eLearning (/web#action=...)
                  │                                   │
                  ▼                                   ▼
        Mở Màn hình Native Flutter            Mở Màn hình In-App WebView
        (Animation chuẩn Flutter)           (Inject Cookie Session Odoo)
```

### 2.2 Đảm bảo Phân quyền 100% Theo Đúng Role (RBAC Security)
- **Cơ chế Server-Side Enforcement:**
  - Danh sách Menu **tuyệt đối không hardcode trên mobile client**. Mobile gọi phương thức gốc `load_menus` của Odoo.
  - Odoo ORM tự động đối soát `user.groups_id` và record rules của bảng `ir.ui.menu`.
  - **Tài khoản Portal (Khách hàng):** 
    * **Phía Frontend (Flutter):** Ẩn hoàn toàn nút icon "Ứng dụng" trên thanh Bottom Navigation Bar (`isPortal == true`). Thanh điều hướng Portal giữ gọn gàng 4 nút: Home, Chat, Ticket, Tôi (chuẩn Odoo 17/19 và vuahethong.net - không có App Switcher cho Portal).
    * **Phía Backend Odoo:** Nếu gọi API `/api/v1/mobile/menu/apps`, server phát hiện user thuộc `base.group_portal` (share=True) và tự động trả về mảng rỗng `[]` (chặn truy cập ứng dụng nội bộ từ gốc).
  - **Tài khoản Nhân viên thường:** Có nút "Ứng dụng". Tuy nhiên không thấy và không nhận được các menu Kế toán, Tuyển dụng, Cài đặt hệ thống (chỉ thấy các app được phân quyền).
  - **Tài khoản Quản trị viên / Trưởng phòng:** Nhận đầy đủ danh sách menu tương ứng quyền được cấp.
- **Bảo mật tầng WebView:** Session Cookie truyền sang WebView có cùng UID và Session ID với Mobile API. Nếu người dùng cố tình truy cập link trái phép, Backend Odoo trả lỗi `Access Denied (403)` ngay lập tức.

---

## 3. Đặc tả API Backend Odoo (`v_mobile_17` & `v_mobile_19`)

### 3.1 Endpoint Tra cứu Menu Ứng dụng
* **Đường dẫn:** `GET /api/v1/mobile/menu/apps`
* **Xác thực:** Bearer Token (JWT Mobile)
* **Quyền hạn:** Mọi tài khoản hợp lệ (Odoo tự lọc theo `request.env.user`).

### 3.2 Cấu trúc Dữ liệu Phản hồi (JSON Response)
```json
{
  "status": "success",
  "data": {
    "apps": [
      {
        "id": 102,
        "name": "Chuyên cần",
        "xmlid": "hr_attendance.menu_hr_attendance_root",
        "action_id": 145,
        "web_icon": "hr_attendance,static/description/icon.png",
        "web_icon_data": "data:image/png;base64,iVBORw0KGgo...",
        "native_route": "/timesheet",
        "is_native": true
      },
      {
        "id": 105,
        "name": "Kế toán",
        "xmlid": "account.menu_finance",
        "action_id": 210,
        "web_icon": "account,static/description/icon.png",
        "web_icon_data": "data:image/png;base64,iVBORw0KGgo...",
        "native_route": null,
        "web_url": "/web#action=210&menu_id=105",
        "is_native": false
      }
    ],
    "utilities": [
      {
        "id": "docs",
        "name": "Tài liệu hướng dẫn",
        "icon": "book_open",
        "url": "/help/docs"
      },
      {
        "id": "support",
        "name": "Yêu cầu hỗ trợ",
        "icon": "life_buoy",
        "native_route": "/tickets"
      },
      {
        "id": "settings",
        "name": "Cài đặt hệ thống",
        "icon": "settings",
        "web_url": "/web#action=base.action_res_users"
      }
    ]
  }
}
```

---

## 4. Đặc tả Giao diện & Trải nghiệm Flutter (`vclients`)

### 4.1 Cập nhật Thanh Điều Hướng Đáy (`AppScaffold`)
Thêm nút thứ 3 hoặc nút giữa vào thanh điều hướng đáy:
* **Icon:** `LucideIcons.layoutGrid` (lưới 4 ô vuông sắc nét).
* **Nhãn (Label):** `Menu` hoặc `Ứng dụng`.
* **Hành vi (Tap):** Không chuyển route toàn trang mà mở `showModalBottomSheet`.

### 4.2 Thiết kế Khung Trượt Đáy (`AppDrawerBottomSheet`)
* **Kiểu hiển thị:** `DraggableScrollableSheet` có bo tròn góc trên 24px (`borderRadius: BorderRadius.vertical(top: Radius.circular(24))`).
* **Kích thước:** Chiếm 85% chiều cao màn hình, hỗ trợ vuốt xuống để đóng.
* **Bộ lọc Tab trên cùng:**
  * `Bookmark`: Danh sách các ứng dụng người dùng thường xuyên ghim.
  * `All apps` (Mặc định active): Toàn bộ ứng dụng được cấp quyền.
* **Khu vực Lưới Ứng dụng (App Grid Area):**
  * Chia lưới 4 cột đồng đều (`crossAxisCount: 4`).
  * Card ứng dụng:
    * Khung chứa icon bo tròn 16px squash badge với nền kính mờ/đổ bóng nhẹ công nghệ cao.
    * Tải icon từ SVG/PNG Base64 do backend trả về hoặc fallback bộ icon Lucide đồng bộ thương hiệu 360 CORP.
    * Tiêu đề ứng dụng bên dưới: Cỡ chữ 12px, tối đa 2 dòng, căn giữa, màu Slate 900 (Light) hoặc Slate 100 (Dark).
* **Khu vực Tiện ích Hệ thống (System Utilities Section):**
  * Nằm ở chân sheet, phân tách bằng đường kẻ mờ `Divider`.
  * Tiêu đề nhỏ: `TIỆN ÍCH HỆ THỐNG` (chữ hoa, 11px, màu Slate 500).
  * Danh sách dạng hàng list-tile:
    * 📖 Tài liệu hướng dẫn
    * 🎧 Yêu cầu hỗ trợ (gắn badge số ticket đang mở nếu có)
    * ⚙️ Cài đặt hệ thống

---

## 5. Kỹ thuật Màn hình In-App WebView (`OdooWebViewScreen`)

### 5.1 Cấu hình Engine WebView
* **Thư viện chuẩn:** `webview_flutter: ^4.10.0`
* **Cơ chế đồng bộ phiên (Session Injection):**
  * Trích xuất session cookie từ `OdooApiClient` (`session_id=...`).
  * Sử dụng `WebViewCookieManager` nạp cookie vào domain Odoo trước khi load trang:
    ```dart
    await WebViewCookieManager().setCookie(
      WebViewCookie(
        name: 'session_id',
        value: currentOdooSessionId,
        domain: Uri.parse(baseUrl).host,
      ),
    );
    ```
* **Tùy biến Giao diện WebView:**
  * Ẩn thanh header/navbar mặc định cồng kềnh của Odoo Web trên mobile bằng CSS injection (`display: none !important;`) để ứng dụng nhìn như Native.
  * Thêm thanh công cụ chuẩn Native trên cùng: Nút đóng `X`, Tên phân hệ, Nút tải lại (Reload), và Nút mở bằng trình duyệt ngoài nếu cần.

---

## 6. Ma Trận 10 Test Cases Kiểm Thử Bắt Buộc

| STT | Mã Test Case | Điều kiện & Kịch bản Kiểm thử | Kết quả Kỳ vọng |
|---|---|---|---|
| 1 | `TC-RBAC-01` | Đăng nhập tài khoản Nhân viên thường (không có quyền Kế toán). | Icon "Kế toán" hoàn toàn KHÔNG xuất hiện trên lưới Menu. |
| 2 | `TC-RBAC-02` | Đăng nhập tài khoản Quản lý / Kế toán viên. | Icon "Kế toán" xuất hiện đầy đủ, bấm vào mở đúng phân hệ Kế toán. |
| 3 | `TC-RBAC-03` | Đăng nhập tài khoản Khách hàng (Portal User). | Ẩn hoàn toàn nút "Ứng dụng" ở Bottom Bar; gọi API trả về [] (Zero leakage). |
| 4 | `TC-NAV-01` | Bấm vào icon có sẵn Native (Chat, Timesheet, Ticket). | Điều hướng ngay lập tức vào màn hình Native Flutter tương ứng, đóng BottomSheet. |
| 5 | `TC-NAV-02` | Bấm vào icon chưa có Native (Tuyển dụng, eLearning, Khảo sát). | Mở màn hình In-App WebView, tự động xác thực phiên và load trang Odoo tương ứng. |
| 6 | `TC-UI-01` | Mở Menu trên màn hình nhỏ (375x812px) và máy tính bảng (Tablet). | Lưới 4 cột hiển thị sắc nét, không bị tràn màn hình (No RenderFlex overflow). |
| 7 | `TC-UI-02` | Chuyển đổi giữa chế độ Sáng (Light Mode) và Tối (Dark Mode). | Icon và màu chữ tương phản rõ nét, đúng quy chuẩn Brand Blue `#0077cd`. |
| 8 | `TC-SESS-01` | Hết hạn token phiên làm việc (Session expired). | Webview tự động phát hiện, điều hướng về màn hình đăng nhập của App. |
| 9 | `TC-NET-01` | Mất kết nối mạng Internet khi mở Menu. | Hiển thị màn hình báo lỗi mạng thân thiện và nút "Thử lại", không crash app. |
| 10 | `TC-BACK-01` | Bấm nút Back cứng trên Android khi đang mở BottomSheet và WebView. | Lần 1: Thoát WebView về trang trước; Lần 2: Đóng BottomSheet về Home (không văng app). |

---

## 7. Lộ Trình Triển Khai (Roadmap)
1. **Bước 1 (Backend):** Viết controller `/api/v1/mobile/menu/apps` trên `v_mobile_17` & `v_mobile_19`.
2. **Bước 2 (State & DTO):** Tạo model `AppMenuItem` và Riverpod provider `menuAppsProvider` trên `vclients`.
3. **Bước 3 (UI Component):** Thiết kế widget `AppDrawerBottomSheet` lưới 4 cột và gắn icon vào `AppScaffold`.
4. **Bước 4 (WebView Engine):** Tích hợp `webview_flutter` và hoàn thiện `OdooWebViewScreen`.
5. **Bước 5 (QA & Verification):** Chạy đủ 10 test cases, đối soát trên thiết bị thật và báo cáo nghiệm thu Sếp Tân.
