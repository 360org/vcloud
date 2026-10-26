# KẾ HOẠCH TRIỂN KHAI: MENU ỨNG DỤNG ĐÁY & ĐIỀU HƯỚNG LAI GHÉP
*(BOTTOM APP DRAWER & HYBRID WEBVIEW ROUTER)*

> **Dự án:** Vcloud Mobile (`vclients`) & Backend Odoo (`v_mobile_17` / `v_mobile_19`)  
> **Tài liệu tham chiếu:** [SPEC_BOTTOM_APP_DRAWER_HYBRID_WEBVIEW.md](SPEC_BOTTOM_APP_DRAWER_HYBRID_WEBVIEW.md)  
> **Người thực hiện:** Ma Nguyễn Nhật Tân  
> **Ngày lập kế hoạch:** 2026-10-26  

---

## 1. Phân Bổ Giai Đoạn (5 Phases)

### Giai đoạn 1: Backend Odoo API (`v_mobile_17` & `v_mobile_19`)
* **Mục tiêu:** Cung cấp endpoint chuẩn `/api/v1/mobile/menu/apps` lọc danh sách ứng dụng theo đúng quyền hạn (`res.groups`) của tài khoản đang đăng nhập.
* **Tệp can thiệp:**
  - `v_mobile_17/controllers/menu.py` (tạo mới)
  - `v_mobile_17/controllers/__init__.py` (khai báo route)
  - `v_mobile_19/controllers/menu.py` (đồng bộ tương thích Odoo 19 `readonly=False`)
  - `v_mobile_19/controllers/__init__.py`
* **Tiêu chuẩn hoàn thành:**
  - Gọi curl với token tài khoản User thường ➔ Không trả về các menu Kế toán, Tuyển dụng.
  - Gọi curl với token tài khoản Manager ➔ Trả về đầy đủ các app quản trị.
  - Gọi curl với token tài khoản Portal ➔ Trả về mảng rỗng `[]` (chặn cứng từ gốc).

### Giai đoạn 2: Data Model & State Management (`vclients`)
* **Mục tiêu:** Xây dựng tầng Data & Application quản lý danh sách Menu trong Flutter bằng Riverpod.
* **Tệp can thiệp:**
  - `vclients/lib/features/menu/data/menu_item_model.dart`
  - `vclients/lib/features/menu/data/menu_repository.dart`
  - `vclients/lib/features/menu/application/menu_controller.dart`
* **Tiêu chuẩn hoàn thành:**
  - Mock dữ liệu và unit test repository, parse JSON an toàn (fail-soft, không crash khi icon null).

### Giai đoạn 3: Thiết Kế UI App Drawer BottomSheet (`vclients`)
* **Mục tiêu:** Tạo widget BottomSheet trượt từ dưới lên dạng lưới 4 cột đúng như ảnh Sếp gửi.
* **Tệp can thiệp:**
  - `vclients/lib/features/menu/presentation/app_drawer_bottom_sheet.dart`
  - `vclients/lib/features/menu/presentation/widgets/app_grid_card.dart`
  - `vclients/lib/features/menu/presentation/widgets/system_utilities_list.dart`
  - `vclients/lib/shared/widgets/app_scaffold.dart` (Bổ sung nút icon Grid vào thanh Bottom Navigation dành riêng cho Nhân viên, ẩn hoàn toàn đối với Portal)
* **Tiêu chuẩn hoàn thành:**
  - Tài khoản Nhân viên: Bấm vào icon "Ứng dụng" ở Bottom Bar ➔ Mở BottomSheet mượt mà với animation chuẩn Flutter.
  - Tài khoản Portal: Nút "Ứng dụng" hoàn toàn không xuất hiện, giữ 4 tab tinh gọn (Home, Chat, Ticket, Tôi).
  - Hiển thị 2 tab `Bookmark` và `All apps`.
  - Hiển thị khối Tiện ích hệ thống ở dưới đáy.

### Giai đoạn 4: Bộ Định Tuyến Lai Ghép & In-App WebView Engine (`vclients`)
* **Mục tiêu:** Tích hợp `webview_flutter` và bộ điều hướng (Route sang Native nếu có, mở WebView nếu chưa).
* **Tệp can thiệp:**
  - `vclients/pubspec.yaml` (Bổ sung `webview_flutter: ^4.10.0`)
  - `vclients/lib/features/menu/presentation/odoo_webview_screen.dart`
  - `vclients/lib/core/router/app_router.dart` (Thêm route `/webview`)
* **Tiêu chuẩn hoàn thành:**
  - Click vào Chat / Timesheet / Ticket ➔ Điều hướng Native ngay lập tức.
  - Click vào Kế toán / Tuyển dụng ➔ Mở In-App WebView, tự động login session và load trang web Odoo.

### Giai đoạn 5: Kiểm Thử Toàn Diện & Nghiệm Thu
* **Mục tiêu:** Chạy trọn vẹn 10/10 Test Cases trong bảng Ma trận kiểm thử (SPEC Mục 6).
* **Môi trường kiểm thử:**
  - Local Server Docker Odoo 17 & 19
  - Trình duyệt Chrome Web & Thiết bị giả lập/thật Android
* **Tiêu chuẩn hoàn thành:** 10/10 test cases PASS, `flutter analyze` 0 errors / 0 warnings.

---

## 2. Kế Hoạch Dự Phòng & Rollback
* Mọi thay đổi trên thanh Bottom Navigation Bar đều bọc cờ kiểm tra (Feature Flag / Fail-soft).
* Nếu API Menu gặp lỗi mạng hoặc server chưa cập nhật: BottomSheet tự động fallback sang danh mục các ứng dụng offline cơ bản, không làm ảnh hưởng đến các màn hình Native đang hoạt động.
