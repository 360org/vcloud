# 🛑 CLAUDE CODE MASTER EXECUTION CONTRACT: KIỂM TRA & ĐỒNG BỘ TOÀN DIỆN THEME SÁNG / TỐI HỆ THỐNG GIỮA MOBILE & WEB (prompt_theme_sync.md)
# Director: Sếp Tân | Target: Flutter Client (vclients) & Odoo WebView / Backend Addon (v_mobile_17 / v_mobile_19)
# Architecture: Agent OS v3.1 | Standard: Ponytail (Minimal Diff, Max Performance) & Anti-Sycophancy Protocol (Evidence-First)
# Context: Sếp cài Dark Mode trên điện thoại nhưng khi vào Menu Ứng dụng mở Model thì WebView bị ép Sáng; Web và Mobile hiển thị lệch pha.

================================================================================
🏛️ [TRỤ CỘT 1: 👤 MULTI-AGENT TEAM DELEGATION MATRIX & DISPATCH DIRECTIVE]
🚨 PHÂN CÔNG QUYỀN HẠN ĐỘC QUYỀN & CHỈ THỊ ĐIỀU PHỐI (1-FILE-1-OWNER):
- `@lead`: Team Lead Orchestrator (tiếp nhận Master Contract, cắm lock `.claude/task_locks . yaml`, điều phối baton, nhận Terse Ping < 2 dòng, xuất Báo cáo Nghiệm thu UAT Ready Bảng < 1.200 ký tự cho Sếp Tân).
  ⛔ **CẤM TUYỆT ĐỐI**: Không tự gõ lệnh terminal sửa code hoặc chạy test trực tiếp (chống phình to transcript và tràn RAM context).
  🚨 **MANDATORY AGENT DISPATCH DIRECTIVE**: BẮT BUỘC gọi tool `Agent` ủy quyền thực thi cho đội ngũ Subagent chuyên trách:
  * Kiểm toán & Khắc phục Đồng bộ Theme trên Frontend: `Agent({ subagent_type: 'dev-mobile-flutter', prompt: '...' })`
  * Rà soát Theme Preference & Web Asset Bundles Backend: `Agent({ subagent_type: 'dev-backend-odoo', prompt: '...' })`
  * Kiểm thử UAT trên Mobile (Vivo / Redroid) & Web: `Agent({ subagent_type: 'tester-functional', prompt: '...' })`
  * Kiểm toán An toàn, Tương phản Màu sắc (Contrast Ratio) & Ký duyệt: `Agent({ subagent_type: 'audit-gate', prompt: '...' })`
- `@dev-mobile-flutter`: Độc quyền kiểm soát `vclients/lib/features/profile/` và `vclients/lib/features/menu/`:
  * Phẫu thuật `theme_controller . dart:64-74`: Loại bỏ hoàn toàn logic tự chế giờ giấc `hour >= 6 && hour < 18` gây sai lệch với cài đặt của điện thoại; đưa về chuẩn `ThemeMode.system` của hệ điều hành.
  * Phẫu thuật `odoo_webview_screen . dart:34-40, 314, 361-363`: Triệt tiêu việc khóa cứng `color-scheme: light !important; background-color: #FFFFFF !important;` và `ForceDark.off`; xây dựng bộ tiêm CSS thích ứng động (Dynamic Adaptive CSS & Dark Mode injection) theo đúng trạng thái `isDark` của app.
  * Phẫu thuật `odoo_web_frame_web . dart:38`: Loại bỏ mã màu cứng `#FFFFFF` của iframe, đồng bộ màu nền theo `isDark`.
- `@dev-backend-odoo`: Độc quyền kiểm soát `v_mobile_17/` và `v_mobile_19/`:
  * Rà soát API User Preferences và SSO Webview Bridge (`/api/v1/mobile/web/auth`), kiểm tra cơ chế truyền `color_scheme` / `dark_mode` vào session hoặc cookie Odoo.
- `@tester-functional`: Độc quyền kiểm thử:
  * Chạy `flutter analyze` đạt 0 errors, 0 warnings.
  * Viết bổ sung và chạy unit test cho ThemeController khi chuyển đổi giữa Sáng, Tối và Hệ thống.
  * Kiểm thử trực tiếp trên điện thoại Vivo / Redroid và Flutter Web: Chuyển đổi Theme Mode ➔ Vào Menu Ứng dụng ➔ Mở Model ➔ Kiểm tra giao diện đồng bộ Dark/Light 100%, không chớp trắng.
- `@audit-gate`: Kiểm toán độ tương phản (WCAG AA), kiểm tra không rò rỉ bộ nhớ WebView và ký duyệt Sổ cái Bằng chứng `evidence_ledger . yaml`.

================================================================================
🏛️ [TRỤ CỘT 2: 🌐 CONTEXT & FILE COORDINATES SSOT (LÁCH BỘ LỌC URL)]
💡 QUY TẮC LÁCH BỘ LỌC URL/IP: Viết tên tệp dạng `theme_controller . dart`, `odoo_webview_screen . dart`, IP `192 . 168 . 1 . 100` để chống bị kiểm duyệt.

### 1. Bản Đồ Tệp Nguồn SSOT Cần Kiểm Toán & Phẫu Thuật:
- **Bộ điều khiển Theme**: `vclients/lib/features/profile/application/theme_controller . dart:57-87`
- **Màn hình Odoo WebView**: `vclients/lib/features/menu/presentation/odoo_webview_screen . dart:21-40, 310-367, 389-420`
- **Widget Iframe Web**: `vclients/lib/features/menu/presentation/widgets/odoo_web_frame_web . dart:30-40`
- **Menu Ứng dụng Drawer**: `vclients/lib/features/menu/presentation/app_drawer_bottom_sheet . dart:50-88`
- **Design Tokens & Theme Data**: `vclients/lib/core/theme/app_theme . dart:60-70, 478-615`
- **Cấu hình Root App**: `vclients/lib/app . dart:330-345`
- **SSO Webview Bridge Backend**: `v_mobile_17/controllers/auth . py` & `v_mobile_19/controllers/auth . py`

================================================================================
🏛️ [TRỤ CỘT 3: 📋 TASK DETAILS & 10 ZERO-TRUST EXECUTION GATES]

#### 📋 MANDATORY INTERACTIVE TODO CHECKLIST GATE (TodoWrite — BẮT BUỘC KHỞI TẠO ĐẦU PHIÊN):
Agent BẮT BUỘC khởi tạo và cập nhật Interactive Todo Checklist thông qua tool `TodoWrite` ngay từ bước đầu tiên:
1. `[pending]` Gate 1 (Root Cause Audit): Xác minh 4 nguyên nhân gốc rễ gây lệch pha Theme giữa Mobile, WebView và Web.
2. `[pending]` Gate 2 (Fix ThemeController System Mode): Sửa `theme_controller.dart` trả về chuẩn `ThemeMode.system` của điện thoại, xóa bỏ heuristic giờ (6h-18h).
3. `[pending]` Gate 3 (Fix OdooWebViewScreen Dynamic Theme): Xóa bỏ CSS khóa cứng màu Sáng; tiêm CSS Dark Mode và bật `ForceDark` thích ứng khi `isDark == true`.
4. `[pending]` Gate 4 (Fix Web Iframe Background): Sửa `odoo_web_frame_web.dart` đồng bộ màu nền iframe theo Theme đang chọn.
5. `[pending]` Gate 5 (Odoo Web Client Cookie / Query Sync): Rà soát truyền tham số theme (`color_scheme=dark` hoặc `dark_mode=1`) vào WebView URL & SSO.
6. `[pending]` Gate 6 (Static Analysis): Chạy `cd vclients && flutter analyze` đạt tuyệt đối 0 errors, 0 warnings.
7. `[pending]` Gate 7 (Unit & Widget Tests): Bổ sung test case kiểm chứng chuyển đổi Theme và trạng thái WebView thích ứng.
8. `[pending]` Gate 8 (UAT Cross-Device Verification): Kiểm thử thực tế trên điện thoại Vivo V2116 / Redroid Local Server và Flutter Web.
9. `[pending]` Gate 9 (SSOT Docs & Ledger Update): Ghi nhận chi tiết vào `docs/CHANGELOGS.md`, `docs/features.md` và `.claude/agent_state/evidence_ledger.yaml`.
10. `[pending]` Gate 10 (Final Concise Report): Xuất Báo cáo Nghiệm thu UAT Ready (< 1.200 ký tự) cho Sếp Tân.

---

### 🔬 PHẦN 1: 4 NGUYÊN NHÂN GỐC RỄ (ROOT CAUSE ANALYSIS)

1. **Nguyên nhân 1: Heuristic giờ tự chế trong `ThemeController` phá vỡ Theme của Điện thoại**:
   * Tại `vclients/lib/features/profile/application/theme_controller . dart:64-74`, khi người dùng chọn `AppThemeMode.system`, code lại chạy:
     `if (hour >= 6 && hour < 18) return ThemeMode.light; else return ThemeMode.dark;`
   * **Hậu quả**: Nếu Sếp Tân cài điện thoại ở chế độ Dark Mode vào ban ngày (ví dụ 14:00 chiều), ứng dụng lại tự ép về `ThemeMode.light`!
   * **Khắc phục**: Trả về trực tiếp `ThemeMode.system` để Flutter engine tự động đồng bộ theo `platformDispatcher.platformBrightness` của hệ điều hành.

2. **Nguyên nhân 2: Khóa cứng `color-scheme: light !important;` và `ForceDark.off` trong `OdooWebViewScreen`**:
   * Tại `vclients/lib/features/menu/presentation/odoo_webview_screen . dart:34-40`:
     ```css
     :root, html, body {
       color-scheme: light !important;
       background-color: #FFFFFF !important;
     }
     ```
   * Tại dòng 314: `..setBackgroundColor(Colors.white)`
   * Tại dòng 361-363: `await platform.setForceDark(ForceDark.off);`
   * **Hậu quả**: Khi Sếp mở Menu Ứng dụng và chọn bất kỳ Model nào, WebView luôn bị ép hiển thị màu trắng tinh, bất chấp app đang ở Dark Mode!
   * **Khắc phục**: Thay thế bằng cơ chế Dynamic Adaptive Theme. Khi `isDark == true`, tiêm CSS Dark Mode, đặt nền `#0F1729`, và kích hoạt `platform.setForceDark(ForceDark.on)`.

3. **Nguyên nhân 3: Khóa cứng `#FFFFFF` trong `odoo_web_frame_web.dart`**:
   * Tại `vclients/lib/features/menu/presentation/widgets/odoo_web_frame_web . dart:38`:
     `iframe.style..backgroundColor = '#FFFFFF';`
   * **Hậu quả**: Trên trình duyệt Web, iframe Odoo luôn có nền trắng gây chói mắt khi app đang bật giao diện tối.
   * **Khắc phục**: Truyền cờ `isDark` vào `buildHtmlIframe` để gán màu nền `#0F1729` khi ở Dark Mode.

4. **Nguyên nhân 4: Thiếu đồng bộ trạng thái màu sang Web Client Odoo**:
   * Odoo Web Client cần nhận biết người dùng muốn dùng giao diện Sáng hay Tối để áp dụng bảng màu tương ứng (thông qua cookie `color_scheme` hoặc tham số URL).

---

### 🔬 PHẦN 2: TỌA ĐỘ PHẪU THUẬT & CODE TRƯỚC / SAU (READ-BEFORE-WRITE SSOT)

#### 1. TỌA ĐỘ 1: `vclients/lib/features/profile/application/theme_controller.dart:57-76`

**TRƯỚC:**
```dart
extension AppThemeModeX on AppThemeMode {
  ThemeMode get themeMode {
    switch (this) {
      case AppThemeMode.dark:
        return ThemeMode.dark;
      case AppThemeMode.light:
        return ThemeMode.light;
      case AppThemeMode.system:
        final hour = DateTime.now().hour;
        // Theo giờ Việt Nam (UTC+7):
        // Từ 06:00 sáng đến 18:00 tối -> Giao diện Sáng (Light Mode)
        // Từ 18:00 tối đến 06:00 sáng -> Giao diện Tối (Dark Mode)
        if (hour >= 6 && hour < 18) {
          return ThemeMode.light;
        } else {
          return ThemeMode.dark;
        }
    }
  }
```

**SAU (Đồng bộ chuẩn 100% theo hệ điều hành điện thoại):**
```dart
extension AppThemeModeX on AppThemeMode {
  ThemeMode get themeMode {
    switch (this) {
      case AppThemeMode.dark:
        return ThemeMode.dark;
      case AppThemeMode.light:
        return ThemeMode.light;
      case AppThemeMode.system:
        // Chuẩn Native OS: Trả về ThemeMode.system để Flutter engine tự động
        // lắng nghe platformDispatcher.platformBrightness của điện thoại Sếp Tân
        return ThemeMode.system;
    }
  }
```

---

#### 2. TỌA ĐỘ 2: `vclients/lib/features/menu/presentation/odoo_webview_screen.dart`

**TRƯỚC (`odoo_webview_screen . dart:34-40` & `360-365`):**
```css
/* Khóa cứng bảng màu Sáng (Light Theme) và nền trắng cho WebView */
:root, html, body {
  color-scheme: light !important;
  background-color: #FFFFFF !important;
}
```
```dart
if (platform is AndroidWebViewController) {
  // ponytail: Tắt Force Dark để Android WebView không tự ý đảo màu trang Odoo sang nền đen
  await platform.setForceDark(ForceDark.off);
}
```

**SAU (Tạo bộ CSS thích ứng và bật ForceDark thông minh theo `isDark`):**
```dart
/// Sinh CSS tối ưu hóa Native UX và thích ứng chính xác theo Theme Sáng / Tối
String _buildOdooNativeOptimizationCss({required bool isDark}) {
  final colorScheme = isDark ? 'dark' : 'light';
  final bgColor = isDark ? '#0F1729' : '#FFFFFF';
  final textColor = isDark ? '#F1F5F9' : '#0F172A';

  return '''
:root, html, body {
  color-scheme: $colorScheme !important;
  background-color: $bgColor !important;
  color: $textColor !important;
}

/* 1. Ẩn triệt để toàn bộ navbar web Odoo để tránh 2 tầng menu */
.o_main_navbar,
.o_menu_brand,
header.o_navbar,
.o_navbar_apps_menu,
.o_menu_toggle,
.o_mobile_navbar {
  display: none !important;
}

/* 2. Loại bỏ khoảng trống thừa ở đỉnh trang và hiệu ứng tap mờ */
html, body {
  padding-top: 0 !important;
  margin-top: 0 !important;
  -webkit-font-smoothing: antialiased !important;
  -webkit-tap-highlight-color: transparent !important;
  touch-action: pan-x pan-y !important;
  overscroll-behavior-y: none !important;
}

/* 3. Tối ưu vùng nội dung Odoo Action Manager chiếm trọn khung nhìn */
.o_action_manager {
  top: 0 !important;
  height: 100vh !important;
  overflow-y: auto !important;
  background-color: $bgColor !important;
  -webkit-overflow-scrolling: touch !important;
}

/* 4. Tăng tốc phần cứng GPU cho các phần tử cuộn */
.o_content, .o_kanban_view, .o_list_view, .o_form_view {
  transform: translateZ(0);
  -webkit-transform: translateZ(0);
  backface-visibility: hidden;
  -webkit-backface-visibility: hidden;
}

/* 5. Cải thiện độ nhạy và triệt tiêu độ trễ 300ms khi chạm trên mobile */
button, a, .o_dropdown_button, .o_kanban_record, .o_data_row, [role="button"] {
  touch-action: manipulation !important;
}
''';
}
```

Và tại hàm `_initializeWebView()`:
```dart
final isDark = Theme.of(context).brightness == Brightness.dark;
final themeBgColor = isDark ? const Color(0xFF0F1729) : Colors.white;

final controller = WebViewController();
controller
  ..setJavaScriptMode(JavaScriptMode.unrestricted)
  ..setBackgroundColor(themeBgColor)
...
if (!kIsWeb) {
  try {
    await controller.setOverScrollMode(WebViewOverScrollMode.never);
    final platform = controller.platform;
    if (platform is AndroidWebViewController) {
      // Tự động bật Force Dark khi app ở Dark Mode để Android WebView đảo màu đồng bộ
      await platform.setForceDark(isDark ? ForceDark.on : ForceDark.off);
    }
  } catch (e) {
    debugPrint('[VCLOUD_WEBVIEW] controller platform config error: $e');
  }
}
```

---

#### 3. TỌA ĐỘ 3: `vclients/lib/features/menu/presentation/widgets/odoo_web_frame_web.dart:33-40`

**TRƯỚC:**
```dart
iframe.style
  ..width = '100%'
  ..height = '100%'
  ..border = '0'
  ..display = 'block'
  ..backgroundColor = '#FFFFFF';
```

**SAU:**
```dart
Widget? buildHtmlIframe({
  required String url,
  required VoidCallback onLoaded,
  void Function(String error)? onError,
  bool isDark = false,
}) {
...
  iframe.style
    ..width = '100%'
    ..height = '100%'
    ..border = '0'
    ..display = 'block'
    ..backgroundColor = isDark ? '#0F1729' : '#FFFFFF';
```

================================================================================
🏛️ [TRỤ CỘT 4: ⚙️ OUTPUT FORMAT (< 1.200 KÝ TỰ DẠNG BẢNG UAT READY)]
🚨 TẤT CẢ CÁC Ô TRẠNG THÁI BAN ĐẦU BẮT BUỘC ĐỂ `⬜ PENDING`. CẤM ĐIỀN SẴN PASS!

Báo cáo nghiệm thu hoàn thành gửi Sếp Tân bắt buộc theo mẫu:

| STT | Hạng mục kiểm tra & khắc phục | Vị trí Tệp & Dòng mã | Kết quả Đo lường | Trạng thái |
|---|---|---|---|---|
| 1 | Sửa `AppThemeMode.system` theo chuẩn OS | `theme_controller . dart:64` | Trả về `ThemeMode.system` | ⬜ PENDING |
| 2 | Loại bỏ CSS khóa cứng màu Sáng trong WebView | `odoo_webview_screen . dart:34` | Xóa `color-scheme: light` cứng | ⬜ PENDING |
| 3 | Tiêm Dynamic CSS thích ứng Dark/Light | `odoo_webview_screen . dart:390` | Đổi màu theo `isDark` | ⬜ PENDING |
| 4 | Điều khiển Android WebView `setForceDark` | `odoo_webview_screen . dart:361` | Bật `on` khi Dark, `off` khi Light | ⬜ PENDING |
| 5 | Đồng bộ màu nền WebView `setBackgroundColor` | `odoo_webview_screen . dart:314` | `#0F1729` (Tối) / `#FFFFFF` (Sáng) | ⬜ PENDING |
| 6 | Đồng bộ màu nền Iframe trên Web | `odoo_web_frame_web . dart:38` | Màu nền iframe theo `isDark` | ⬜ PENDING |
| 7 | Static Analysis Code Quality | `flutter analyze` | 0 errors, 0 warnings | ⬜ PENDING |
| 8 | Unit Tests chuyển đổi ThemeMode | `test/features/profile/` | Pass 100% test cases | ⬜ PENDING |
| 9 | Kiểm chứng UAT thực tế trên Vivo V2116 | Màn hình Model Odoo | WebView hiển thị Tối đồng bộ | ⬜ PENDING |
| 10 | Kiểm chứng UAT trên Redroid & Web | Local Server `192.168.1.100` | Giao diện đồng nhất không lệch pha | ⬜ PENDING |

================================================================================
🥊 [ANTI-SYCOPHANCY & CALIBRATED CONFIDENCE PROTOCOL (v2)]
1. **CLAIM ≠ FACT**: "Đã đồng bộ Theme thành công" chỉ được chấp nhận khi có ảnh chụp màn hình thực tế trên điện thoại Vivo / Redroid chứng minh WebView hiển thị nền Tối `#0F1729` khi máy ở Dark Mode.
2. **Thang đo L0-L5**: Sửa code mới chỉ đạt `L2 SUPPORTED`. Chạy unit test đạt `L3 REPRODUCED`. Phải test thực tế trên WebView Android mới đạt `L4 VERIFIED`.
3. **Cấm số ảo**: Báo cáo trung thực mã màu hex thực tế đo được trên thanh AppBar và thân WebView.
4. **Tập lệnh kiểm chứng bắt buộc**:
   ```bash
   cd /media/tanma/DATA/save/mobile_versions/vclients
   flutter analyze
   flutter test test/features/profile/
   ```

================================================================================
🏛️ [TRỤ CỘT 5: 🌐 QUY CHUẨN ĐỒNG BỘ GIT (git . md)]
Bắt buộc tuân thủ 100% hợp đồng [git.md](git.md) trước và sau khi thực hiện:
1. `vcloud-sync check` trước khi sửa.
2. Safe pull & rebase nếu remote có commit mới.
3. Commit chuẩn kèm trailer: `Authored-By: 360org <support@360.org.vn>`.
4. Push đầy đủ code lên `github/main` sau khi kiểm chứng đạt chuẩn.
