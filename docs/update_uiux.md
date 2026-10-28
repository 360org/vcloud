# Kế Hoạch & Ý Tưởng Nâng Cấp UI/UX Chat VCloud (Mobile Flutter)

> **File:** `docs/update_uiux.md`  
> **Áp dụng cho:** Ứng dụng di động Vcloud (`vclients/`)  
> **Phong cách định hướng:** Refined Tech Luxury & Clean Corporate (Tiêu chuẩn Telegram Premium, Slack, Linear)  
> **Trạng thái:** DRAFTING / Ý TƯỞNG THIẾT KẾ (Chưa sửa code)  
> **Ngày cập nhật:** 2026-10-28  

---

## 1. Mục Tiêu & Bối Cảnh

Module Chat (Trò chuyện nội bộ & Odoo Discuss) là một trong những tính năng cốt lõi được sử dụng hàng ngày của Vcloud. Giao diện hiện tại được xây dựng từ các phiên bản đầu, bộc lộ nhiều điểm nghẽn về thị giác, thiếu độ tương phản, nền họa tiết gây rối mắt và lạm dụng tông màu xanh lá cây pastel cũ kỹ.

Mục tiêu của đợt nâng cấp:
1. **Hiện đại hóa toàn diện giao diện Chat**: Mang đến trải nghiệm mượt mà, đẳng cấp, chuyên nghiệp như các ứng dụng nhắn tin hàng đầu thế giới (Telegram, Slack, Discord).
2. **Cân bằng thị giác & Chuẩn hóa Brand 360 CORP**: Kết hợp hài hòa giữa **Tech Royal Blue (`#0077CD`)** sang trọng và **Digital Green (`#00C83A`)** năng động trên nền xám trắng công nghệ (**Slate Canvas `#F8FAFC`**).
3. **Tối ưu khả năng đọc & Tập trung nội dung (Content-First)**: Loại bỏ các chi tiết thừa thãi, tăng cường độ sắc nét của chữ và hình ảnh, bảo vệ thị lực người dùng khi làm việc liên tục.

---

## 2. Phân Tích Thực Trạng UI/UX Hiện Tại (As-Is Audit)

| Thành phần | File & Dòng Code Hiện Tại | Thực Trạng & Điểm Nghẽn |
|---|---|---|
| **Hình nền (Background)** | [`vclients/lib/features/chat/presentation/widgets/chat_wallpaper.dart:30-65`](/media/tanma/DATA/save/mobile_versions/vclients/lib/features/chat/presentation/widgets/chat_wallpaper.dart:30)<br>[`chat_detail_screen.dart:170`](/media/tanma/DATA/save/mobile_versions/vclients/lib/features/chat/presentation/chat_detail_screen.dart:170) | • Background cứng màu `Color(0xFFDDF3D9)` (xanh ngả vàng).<br>• Gradient: `[#E8F5B8, #BFE9C9, #8ED8BE]`.<br>• Rải lưới icon xoay ngẫu nhiên (`LucideIcons.messageCircle, LucideIcons.coffee...`) phủ dày đặc toàn màn hình.<br>👉 **Nhược điểm:** Cực kỳ rối mắt, màu xanh pastel ngả vàng xỉn giống giao diện WhatsApp cũ, làm chìm nội dung chữ và gây mỏi mắt. |
| **Bong bóng đến (Incoming)** | [`vclients/lib/features/chat/presentation/widgets/chat_bubbles.dart:34-38`](/media/tanma/DATA/save/mobile_versions/vclients/lib/features/chat/presentation/widgets/chat_bubbles.dart:34) | • Nền: `Color(0xFFE7F8E7)` (xanh bạc hà nhạt).<br>• Viền: `Color(0xFFC8EFD0)`.<br>👉 **Nhược điểm:** Màu bong bóng gần như hòa lẫn vào hình nền xanh ngả vàng, làm mất ranh giới phân tách (contrast thấp), đọc chữ ngoài trời hoặc môi trường sáng bị mờ. |
| **Bong bóng đi (Mine)** | [`vclients/lib/features/chat/presentation/widgets/chat_bubbles.dart:726-728`](/media/tanma/DATA/save/mobile_versions/vclients/lib/features/chat/presentation/widgets/chat_bubbles.dart:726) | • Nền: `AppColors.primary` (`#00C83A` - xanh lá cây đậm).<br>👉 **Nhược điểm:** Toàn bộ màn hình bị "bội thực sắc xanh lá" (nền xanh + tin đến xanh ngọc + tin đi xanh lá), thiếu điểm nhấn công nghệ cao cấp. |
| **Khung nhập liệu (Composer)** | [`vclients/lib/features/chat/presentation/widgets/chat_composer.dart:273-355`](/media/tanma/DATA/save/mobile_versions/vclients/lib/features/chat/presentation/widgets/chat_composer.dart:273) | • Thanh nhập dạng kính mờ lơ lửng `gradient alpha 0 -> 0.34`.<br>• Nút đính kèm tròn nổi tách biệt.<br>👉 **Nhược điểm:** Cảm giác chông chênh, không có đáy cố định vững chãi khi bàn phím ảo bật lên; placeholder chữ mờ khó nhìn trên nền kính. |
| **Thanh tiêu đề (Header)** | [`vclients/lib/features/chat/presentation/widgets/chat_header.dart:35-150`](/media/tanma/DATA/save/mobile_versions/vclients/lib/features/chat/presentation/widgets/chat_header.dart:35) | • Dạng viên thuốc nổi (pill floating) bo tròn `radius: 999` lơ lửng giữa màn hình.<br>👉 **Nhược điểm:** Chiếm nhiều khoảng trống dọc, khi cuộn tin nhắn lên đỉnh thì chữ trôi lọt qua khe bên dưới kính mờ tạo cảm giác lem nhem, thiếu chuyên nghiệp. |

---

## 3. Bản Thiết Kế Đề Xuất Mới (To-Be Architecture)

### 3.1. Phác Thảo Bố Cục Trực Quan (ASCII Wireframe)

```text
┌────────────────────────────────────────────────────────────────────────┐
│ [←]  (Avatar)  Châu Trọng Tân                          [📞] [ℹ️]      │ ← Solid Top Bar, Blur 20px,
│                ● Đang trực tuyến (Vua Hệ Thống)                        │   Viền đáy mảnh #E2E8F0
├────────────────────────────────────────────────────────────────────────┤
│                                                                        │
│                          [ Hôm nay, 28/10/2026 ]                       │ ← Date Pill tinh tế (Slate 100/500)
│                                                                        │
│  (Ava) ┌──────────────────────────────────────────────┐                │
│        │ Chào anh Tân, tính năng SSO WebView và       │  08:30         │ ← Incoming Bubble:
│        │ Cài đặt hệ thống đã test pass trên Redroid.  │                │   Trắng tinh #FFFFFF, viền Slate 200,
│        └──────────────────────────────────────────────┘                │   Chữ Slate 900 sắc nét
│                                                                        │
│                      ┌──────────────────────────────────────────────┐  │
│                      │ Quá tốt em! Giờ mình nâng cấp giao diện      │  │ ← Outgoing Bubble (Mine):
│                      │ chat cho sang xịn, hiện đại hơn nhé.         │  │   Tech Royal Blue (#0077CD)
│                      │                                        08:32 │  │   Chữ trắng tuyết, icon ✓✓ thanh mảnh
│                      │                                           ✓✓ │  │
│                      └──────────────────────────────────────────────┘  │
│                                                                        │
│  (Ava) ┌──────────────────────────────────────────────┐                │
│        │ 📊 KHẢO SÁT GIAO DIỆN MỚI                    │                │ ← Card Khảo sát / File đính kèm:
│        │ Anh chọn tone màu nào cho tin nhắn gửi đi?   │                │   Phẳng, bo góc 14px, tương phản cao
│        │ ┌──────────────────────────────────────────┐ │                │
│        │ │ ◉ 1. Tech Royal Blue (#0077CD)           │ │                │
│        │ └──────────────────────────────────────────┘ │                │
│        │ ┌──────────────────────────────────────────┐ │                │
│        │ │ ○ 2. Emerald Brand Green (#00C83A)       │ │                │
│        │ └──────────────────────────────────────────┘ │                │
│        │ 2 lượt bình chọn                       08:35 │                │
│        └──────────────────────────────────────────────┘                │
│                                                                        │
├────────────────────────────────────────────────────────────────────────┤
│  [+]  [ Nhập tin nhắn...                                      😊 ] [➤] │ ← Thanh Input gắn liền đáy,
└────────────────────────────────────────────────────────────────────────┘   nền trắng vững chãi, bo góc mềm
```

---

## 4. Chi Tiết Ý Tưởng & Giải Pháp Thiết Kế

### 4.1. Nâng Cấp Background (Hình Nền)
*   **Loại bỏ hoàn toàn icon doodle lộn xộn**: Xóa bỏ mảng lặp icon xoay ngẫu nhiên gây nhức mắt.
*   **Định hình 2 phương án nền công nghệ**:
    *   **Phương án 1 (Clean Canvas — Khuyên dùng số 1)**: Nền phẳng hoàn toàn màu **`#F8FAFC` (Slate 50)** cho Light Mode và **`#0B101E` (Midnight Dark)** cho Dark Mode. Nền phẳng giúp tăng tốc độ render (0 CPU overhead), làm nổi bật ảnh, file và nội dung trao đổi.
    *   **Phương án 2 (Subtle Tech Grid)**: Nền Slate 50 kết hợp họa tiết chấm tròn kỹ thuật số (Dot Matrix) hoặc đường lưới ô vuông vi mô cực mờ (`opacity: 0.02 - 0.03`, màu `#0077CD`), tạo chiều sâu không gian số mà không làm rối mắt.

### 4.2. Nâng Cấp Bong Bóng Tin Nhắn (Message Bubbles)
*   **Tin nhắn đến (Incoming Messages)**:
    *   **Màu nền**: Trắng tinh khiết **`#FFFFFF`** (Light Mode) / Xám than cao cấp **`#1E293B` (Slate 800)** (Dark Mode).
    *   **Đường viền**: Border siêu mảnh `1px` màu **`#E2E8F0` (Slate 200)** giúp bong bóng tách biệt rõ ràng khỏi nền canvas mà không thô cứng.
    *   **Màu chữ**: **Slate 900 (`#0F172A`)** — độ tương phản đạt chuẩn WCAG AAA, đọc cực kỳ rõ nét trong mọi điều kiện ánh sáng.
    *   **Đổ bóng**: Đổ bóng đa tầng siêu nhẹ chuẩn iOS 18: `BoxShadow(color: Color(0x0A0F172A), blurRadius: 6, offset: Offset(0, 2))`.
*   **Tin nhắn đi (Outgoing / Mine Messages)**:
    *   **Màu sắc chủ đạo (Chuẩn 360 CORP)**: Gradient **Tech Royal Blue (`#0077CD` ➔ `#0066B3`)**.
    *   **Màu chữ**: Trắng tinh (`#FFFFFF`), chữ đậm vừa phải (`FontWeight.w500`).
    *   **Biểu tượng trạng thái**: Cặp dấu tick đọc (Read Receipts `✓✓`) màu xanh ngọc nhạt (`#BAE6FD`) hoặc trắng mờ.
*   **Bo góc thông minh (Intelligent Bubble Burst Radius)**:
    *   Tin nhắn đơn lẻ: Bo tròn `18px`.
    *   Chuỗi tin nhắn liên tiếp cùng người gửi:
        *   Tin nhắn đầu: Bo góc dưới phía đuôi còn `4px`.
        *   Tin nhắn giữa: Bo cả góc trên và dưới phía đuôi còn `4px`.
        *   Tin nhắn cuối: Bo góc trên phía đuôi còn `4px`.
        *   👉 Giúp gom nhóm tin nhắn trực quan, gọn gàng, giảm cảm giác rời rạc.

### 4.3. Nâng Cấp Khung Soạn Thảo Đáy (Composer Bar)
*   **Cấu trúc vững chãi**: Không làm thanh lơ lửng. Thanh composer gắn liền với mép đáy màn hình, có đường phân cách trên `Border(top: BorderSide(color: Color(0xFFE2E8F0), width: 1))`.
*   **Màu nền bar**: Trắng sáng `#FFFFFF` (hoặc Dark `#1E293B`).
*   **Hộp nhập văn bản (Input Field)**:
    *   Thiết kế dạng capsule bo tròn `22px`.
    *   Nền hộp: Xám nhạt **`#F1F5F9` (Slate 100)**, không viền, tạo cảm giác mềm mại và dễ chịu.
    *   Placeholder: Màu **`#64748B` (Slate 500)** hiển thị rõ: *"Nhập tin nhắn..."*.
*   **Nút Thao Tác (Actions)**:
    *   Nút Thêm `+` (Đính kèm file, ảnh, camera, poll): Nút tròn phẳng xám nhẹ với icon sắc nét.
    *   Nút Gửi `Send`: Khi có text nhập vào, nút Gửi chuyển sang màu **Tech Royal Blue `#0077CD`** có hiệu ứng scale hoạt họa mượt mà (Spring curve).

### 4.4. Nâng Cấp Thanh Tiêu Đề Đỉnh (Top App Bar Header)
*   **Cố định vững chãi (Pinned Top Bar)**: Chuyển từ floating pill lơ lửng sang App Bar tiêu chuẩn gắn mép trên.
*   **Hiệu ứng mờ nền**: Sử dụng `BackdropFilter(sigmaX: 16, sigmaY: 16)` với màu nền trắng mờ `Colors.white.withOpacity(0.92)` kèm border đáy `1px` màu `#E2E8F0`. Khi cuộn tin nhắn lên, nội dung mờ dần tinh tế dưới thanh bar thay vì lộ kẽ hở.
*   **Thông tin người dùng / Kênh**:
    *   Avatar tròn có viền trắng mỏng `1.5px`.
    *   Chấm trạng thái Online xanh lá `#22C55E` dạng badge đè nhẹ góc avatar.
    *   Tên hiển thị: Slate 900 `#0F172A`, font size `16px`, `FontWeight.w700`.
    *   Sub-status: *"Đang trực tuyến"* hoặc *"3 thành viên"* màu Slate 500 `#64748B`.

---

## 5. Bảng So Sánh Trước & Sau Nâng Cấp (Before vs. After Matrix)

| Tiêu Chí | Thiết Kế Cũ (Hiện Tại) | Thiết Kế Mới Đề Xuất | Lợi Ích Mang Lại |
|---|---|---|---|
| **Màu sắc nền** | Xanh ngả vàng `#E8F5B8` + icon rối mắt | Slate Canvas `#F8FAFC` phẳng sạch sẽ | Tăng độ tập trung, giảm mỏi mắt, chuyên nghiệp 100% |
| **Bong bóng tin đến** | Xanh ngọc nhạt `#E7F8E7` chìm nền | Trắng tinh `#FFFFFF` + viền Slate 200 | Độ tương phản cao chuẩn WCAG AAA, đọc chữ cực nét |
| **Bong bóng tin đi** | Xanh lá cây đơn điệu `#00C83A` | Tech Royal Blue `#0077CD` ➔ `#0066B3` | Cân bằng thị giác, chuẩn nhận diện 360 CORP cao cấp |
| **Khung nhập liệu** | Lơ lửng, thiếu viền phân cách đáy | Gắn đáy chắc chắn, nền trắng + input Slate 100 | Vững chãi khi bàn phím ảo bật lên, gõ tin dễ chịu |
| **Header** | Pill nổi lơ lửng, hở đáy khi cuộn | Cố định mép trên, kính mờ làm mịn 16px | Trải nghiệm cuộn mượt mà, không bị lẫn chữ |
| **Hiệu năng Render** | Render hàng trăm icon xoay ngẫu nhiên | Layout phẳng, tối ưu hóa widget tree | Tiết kiệm pin, mượt mà 60-120 FPS trên mọi thiết bị |

---

## 6. Lộ Trình Triển Khai Kỹ Thuật (Khi Sếp Duyệt Code)

Khi Sếp Tân phê duyệt triển khai, các bước sửa đổi mã nguồn sẽ tuân thủ nghiêm ngặt nguyên tắc **Ponytail** (tối giản diff, không sinh file rác, tái sử dụng component hiện có):

1. **Bước 1 — Cập nhật Wallpaper & Background Canvas**:
   * Sửa [`vclients/lib/features/chat/presentation/widgets/chat_wallpaper.dart`](/media/tanma/DATA/save/mobile_versions/vclients/lib/features/chat/presentation/widgets/chat_wallpaper.dart): Thay thế gradient xanh úa bằng Slate Canvas `#F8FAFC` (Light) và `#0B101E` (Dark). Bỏ vòng lặp icon doodle.
   * Sửa [`vclients/lib/features/chat/presentation/chat_detail_screen.dart:170`](/media/tanma/DATA/save/mobile_versions/vclients/lib/features/chat/presentation/chat_detail_screen.dart:170): Đổi `Color(0xFFDDF3D9)` sang `context.isDarkMode ? AppColors.darkBg : const Color(0xFFF8FAFC)`.
2. **Bước 2 — Cập nhật Bong bóng tin nhắn (Bubbles)**:
   * Sửa [`vclients/lib/features/chat/presentation/widgets/chat_bubbles.dart`](/media/tanma/DATA/save/mobile_versions/vclients/lib/features/chat/presentation/widgets/chat_bubbles.dart):
     - `getIncomingBubbleColor`: Trả về `Colors.white` (Light) / `Color(0xFF1E293B)` (Dark).
     - `getIncomingBubbleBorder`: Trả về `Color(0xFFE2E8F0)` (Light) / `Color(0xFF334155)` (Dark).
     - Bubble gửi đi (`mine`): Dùng gradient `Color(0xFF0077CD)` và `Color(0xFF0066B3)` hoặc màu đồng bộ thương hiệu.
     - Tinh chỉnh shadow và bo góc liên tiếp.
3. **Bước 3 — Cập nhật Composer Bar**:
   * Sửa [`vclients/lib/features/chat/presentation/widgets/chat_composer.dart`](/media/tanma/DATA/save/mobile_versions/vclients/lib/features/chat/presentation/widgets/chat_composer.dart): Đổi container sang nền solid trắng có border top, tinh chỉnh ô input pill xám nhạt `#F1F5F9`.
4. **Bước 4 — Cập nhật Header**:
   * Sửa [`vclients/lib/features/chat/presentation/widgets/chat_header.dart`](/media/tanma/DATA/save/mobile_versions/vclients/lib/features/chat/presentation/widgets/chat_header.dart): Cố định top bar với kính mờ và border đáy thanh mảnh.
5. **Bước 5 — Kiểm thử & Nghiệm thu trên Redroid Local Server**:
   * Chạy `flutter analyze` đảm bảo 0 errors / 0 warnings.
   * Build APK / chạy trên Redroid Docker Local Server (`192.168.1.100:5555`).
   * Chụp ảnh evidence kiểm chứng giao diện thực tế gửi Sếp nghiệm thu.
