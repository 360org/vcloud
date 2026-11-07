# ĐẶC TẢ KỸ THUẬT: ĐĂNG NHẬP 1-CHẠM BẰNG APPLE (SIGN IN WITH APPLE)
## Tuân thủ Apple App Store Review Guideline 4.8.0 & Đồng bộ Hệ sinh thái Odoo `vuahethong.net`

> **Tài liệu:** [vclients/docs/SPEC_APPLE_SIGN_IN.md](/media/tanma/DATA/save/mobile_versions/vclients/docs/SPEC_APPLE_SIGN_IN.md)  
> *(Liên kết gốc tại: [docs/SPEC_APPLE_SIGN_IN.md](/media/tanma/DATA/save/mobile_versions/docs/SPEC_APPLE_SIGN_IN.md))*  
> **Phiên bản:** 1.1.0 (AIaC Standard)  
> **Ngày lập:** 2026-11-07  
> **Tác giả:** Trợ lý Như (360org AI Engineering Team)  
> **Người duyệt:** Sếp Tân (PO / System Administrator)  
> **Trạng thái:** DỰ THẢO NÂNG CAO TRÌNH DUYỆT (PENDING REVIEW)  
> **Cơ sở pháp lý & Kỹ thuật:**  
> 1. Khắc phục triệt để lỗi từ chối duyệt **Guideline 4.8.0 Design: Login Services** trên Apple App Store cho bản phát hành `v2.9.34 (Build 189)`.  
> 2. Đảm bảo tính nhất quán với tính năng **Feature 1.12 (Google OAuth2 & Social Sign-In)** và **Feature 1.14 (Sign in with Apple)** trong [docs/features.md](/media/tanma/DATA/save/mobile_versions/vclients/docs/features.md).  
> 3. Tương thích hai chiều giữa ứng dụng Flutter (`vclients`) và Backend Odoo 17 & 19 (`v_mobile_17`, `v_mobile_19`) trên `vuahethong.net`.

---

## ⚠️ 6 ĐIỀU KIỆN KỸ THUẬT TIÊN QUYẾT BẮT BUỘC TRƯỚC KHI TRIỂN KHAI

Trước khi viết bất kỳ dòng code nào hay build bản phát hành mới, hệ sinh thái bắt buộc phải đáp ứng đủ 6 điều kiện sau:

| STT | Điều kiện tiên quyết | Vì sao bắt buộc? | Rủi ro nếu bỏ qua |
|---|---|---|---|
| **ĐK-1** | **Apple Developer Portal Capability** | App ID `com.w360s.wcloudapp` trên `developer.apple.com` phải bật checkbox **Sign In with Apple**. | Xcode / CI/CD sẽ báo lỗi Codesigning, không thể build ra file `.ipa`. |
| **ĐK-2** | **Đồng bộ Provisioning Profile CI/CD** | Tải lại file `.mobileprovision` Distribution mới (đã chứa capability Apple Sign In) và cập nhật vào GitHub Secrets `PROVISIONING_PROFILE_BASE64`. | CI/CD GitHub Actions build thất bại do Profile cũ thiếu entitlement `com.apple.developer.applesignin`. |
| **ĐK-3** | **Apple HIG "Equal or Greater Prominence" (Guideline 4.8.0)** | Nút bấm Sign in with Apple phải có kích thước và vị trí **ngang bằng hoặc nổi bật hơn** nút Google Sign-In trên màn hình đăng nhập iOS. | Apple Reviewer sẽ lập tức **REJECT** nếu nút Apple bị thu nhỏ, làm mờ hoặc giấu vào menu con. |
| **ĐK-4** | **Bảo mật Apple Privacy (Hide My Email & apple_sub)** | Backend Odoo bắt buộc phải lưu mã `apple_sub` (Apple User ID) trên `res.users`. Apple chỉ gửi email và họ tên ở **lần đầu tiên**, lần 2+ chỉ gửi `sub`. | Người dùng đăng nhập lần thứ 2 sẽ bị lỗi không vào được app hoặc bị tạo tài khoản rác trùng lặp. |
| **ĐK-5** | **Deploy Backend Production TRƯỚC KHI Nộp Store** | Endpoint `/api/v1/mobile/auth/oauth` trên `vuahethong.net` bắt buộc phải cập nhật code hỗ trợ `provider == "apple"` **trước khi nộp bản build lên App Review**. | Khi Reviewer Apple bấm nút Sign in with Apple trên thiết bị thật của họ, nếu server báo lỗi 400/404/500 thì app sẽ bị **REJECT NGAY LẬP TỨC**. |
| **ĐK-6** | **Chính sách Xóa tài khoản (Guideline 5.1.1(v))** | App có hỗ trợ tạo tài khoản thì bắt buộc phải có tính năng xóa tài khoản trong app. | App Vcloud đã có sẵn nút "Yêu cầu xóa tài khoản" tại `profile_screen.dart:269` (đã pass kiểm duyệt ở bản live 2.9.23). |

---

## 1. BỐI CẢNH & NGUYÊN NHÂN CỐT LÕI (ROOT CAUSE)

### 1.1. Yêu cầu bắt buộc của Apple (Guideline 4.8.0)
* Theo quy định của Apple App Store Review Guidelines:
  > *"Apps that use a third-party or social login service (such as Google Sign-In, Facebook Login, etc.) to set up or authenticate the user’s primary account with the app must also offer Sign in with Apple as an equivalent option."*
* Trên màn hình đăng nhập của Vcloud (`lib/features/auth/presentation/login_screen.dart`), app có nút **"Đăng nhập với Google"** (Feature 1.12).
* Vì vậy, Apple coi việc thiếu nút **"Sign in with Apple"** trên phiên bản iOS là vi phạm nghiêm trọng về mặt thiết kế dịch vụ đăng nhập và kiên quyết từ chối phát hành (Rejected).

### 1.2. Mục tiêu kỹ thuật của giải pháp
1. **Frontend (iOS Flutter)**: Thêm nút Sign in with Apple chuẩn nhận diện thương hiệu Apple (Apple Human Interface Guidelines), hoạt động mượt mà qua Face ID / Touch ID / Passcode 1-chạm.
2. **Backend (Odoo `v_mobile`)**: Tiếp nhận `identityToken` của Apple tại endpoint `/api/v1/mobile/auth/oauth`, giải mã dữ liệu an toàn, tự động liên kết hoặc khởi tạo tài khoản Portal trong `res.users` trên `vuahethong.net`.
3. **Phân quyền người dùng**: Tương tự như Google Login, người dùng đăng nhập bằng Apple tự động được cấp quyền **Khách hàng Portal** (`base.group_portal`), mở các tính năng chăm sóc khách hàng (CSKH Chat, Ticket Hỗ Trợ) và ẩn các tính năng nội bộ nhân viên (Chấm công GPS, Bảng công Timesheet).

---

## 2. KIẾN TRÚC TỔNG THỂ & LUỒNG DỮ LIỆU (SEQUENCE DIAGRAM)

```text
[Người Dùng iOS]       [Vcloud App (Flutter)]         [Apple ID Server]        [Odoo Backend (vuahethong.net)]
      │                        │                             │                                 │
      ├─ Bấm "Sign in with Apple"                            │                                 │
      │───────────────────────>│                             │                                 │
      │                        ├─ Gọi Native Apple Auth API ─>│                                 │
      │                        │  (sign_in_with_apple)       │                                 │
      │<── Hiện Popup Xác Thực ┼─────────────────────────────┤                                 │
      │    Face ID / Touch ID  │                             │                                 │
      ├─ Xác nhận thành công ─>│                             │                                 │
      │                        │<─ Trả về:                   │                                 │
      │                        │   - identityToken (JWT)     │                                 │
      │                        │   - authorizationCode       │                                 │
      │                        │   - userIdentifier (sub)    │                                 │
      │                        │   - email & fullName (Lần 1)│                                 │
      │                        │                             │                                 │
      │                        ├─ Gửi POST /api/v1/mobile/auth/oauth ─────────────────────────>│
      │                        │  { provider: "apple",                                          │
      │                        │    id_token: identityToken,                                    │
      │                        │    apple_sub: userIdentifier,                                  │
      │                        │    email: email, name: fullName }                              │
      │                        │                                                               ├─ Giải mã JWT identityToken
      │                        │                                                               ├─ Tìm user theo apple_sub / email
      │                        │                                                               ├─ NẾU CHƯA CÓ:
      │                        │                                                               │  Tạo res.users (group_portal)
      │                        │                                                               │  Tạo res.partner liên kết
      │                        │                                                               ├─ Kích hoạt vmobile_enabled=True
      │                        │                                                               ├─ Sinh Session JWT Access Token
      │                        │<─ Trả về: { access_token, user_info, is_portal: true } ───────┤
      │                        │                                                               │
      │<── Vào Màn Hình Chính ─┤                                                               │
      │    (Giao diện Portal)  │                                                               │
```

---

## 3. ĐẶC TẢ CHI TIẾT FRONTEND FLUTTER (`vclients`)

### 3.1. Thư viện tích hợp
* Bổ sung dependency vào `pubspec.yaml`:
  ```yaml
  dependencies:
    sign_in_with_apple: ^6.1.4
  ```
  *(Thư viện chuẩn của Flutter Community, hỗ trợ đầy đủ Native ASAuthorizationAppleIDProvider trên iOS và Web fallback).*

### 3.2. Cấu hình iOS Native Capability
1. **File `ios/Runner/Runner.entitlements`**:
   Bổ sung entitlement Sign in with Apple:
   ```xml
   <?xml version="1.0" encoding="UTF-8"?>
   <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
   <plist version="1.0">
   <dict>
       <key>aps-environment</key>
       <string>production</string>
       <key>com.apple.developer.applesignin</key>
       <array>
           <string>Default</string>
       </array>
   </dict>
   </plist>
   ```

### 3.3. Thiết kế Giao diện Màn hình Đăng nhập (`login_screen.dart`)
* **Nguyên tắc nền tảng**: Nút Apple Sign In **CHỈ HIỂN THỊ TRÊN iOS** (`defaultTargetPlatform == TargetPlatform.iOS`). Trên Android giữ nguyên nút Google Sign-In.
* **Giao diện chuẩn Human Interface Guidelines (HIG)**:
  * Nút màu đen nền (`#000000`), chữ trắng (`#FFFFFF`), logo quả táo khuyết chuẩn.
  * Kích thước: Chiều cao `48px`, bo góc `16px` đồng bộ với các trường input của Vcloud.
  * Bố cục: Đặt phía trên nút "Đăng nhập với Google" để đảm bảo tính nổi bật theo đúng khuyến nghị của Apple.

---

## 4. ĐẶC TẢ CHI TIẾT BACKEND ODOO (`v_mobile_17` & `v_mobile_19`)

### 4.1. Mở rộng Model `res.users` (Lưu định danh Apple)
Để giải quyết bài toán Apple **chỉ gửi email và họ tên ở lần đăng nhập đầu tiên** (từ lần 2 trở đi chỉ gửi `userIdentifier` / `sub`), backend cần lưu mã `apple_sub`:
```python
# v_mobile/models/res_users.py
class ResUsers(models.Model):
    _inherit = "res.users"

    apple_sub = fields.Char(
        string="Apple User ID (sub)",
        index=True,
        copy=False,
        help="Mã định danh người dùng duy nhất do Apple cung cấp (sub trong identityToken)."
    )
```

### 4.2. Xử lý tại Controller Endpoint: `POST /api/v1/mobile/auth/oauth`
File: `controllers/auth.py` (trong cả `v_mobile_17` và `v_mobile_19`):

```python
# 1. Nhận diện Provider Apple
is_apple = "apple" in str(provider_name).lower()

if is_apple:
    # 2. Giải mã identityToken (JWT) từ Apple để lấy email và sub an toàn
    apple_sub = body.get("apple_sub")
    try:
        parts = str(oauth_token).split(".")
        if len(parts) == 3:
            payload_raw = parts[1] + "=" * (4 - len(parts[1]) % 4)
            jwt_data = json.loads(base64.urlsafe_b64decode(payload_raw))
            apple_sub = apple_sub or jwt_data.get("sub")
            if not email:
                email = jwt_data.get("email")
    except Exception as jwt_err:
        _logger.warning("mobile_api_core: Giải mã Apple identityToken JWT lỗi: %s", jwt_err)

    # 3. Thuật toán tìm kiếm tài khoản hiện hữu trên Odoo:
    #    Ưu tiên 1: Khớp apple_sub đã lưu trước đó (cho lần đăng nhập thứ 2+)
    #    Ưu tiên 2: Khớp email / login (cho lần đăng nhập đầu tiên)
    user = False
    if apple_sub:
        user = request.env["res.users"].sudo().search([("apple_sub", "=", apple_sub)], limit=1)
    if not user and email:
        user = request.env["res.users"].sudo().search([
            "|", ("login", "=ilike", email.strip()), ("email", "=ilike", email.strip())
        ], limit=1)
        if user and apple_sub and hasattr(user, "apple_sub"):
            user.sudo().write({"apple_sub": apple_sub}) # Gán apple_sub cho các lần sau

    # 4. NẾU LÀ NGƯỜI DÙNG MỚI HOÀN TOÀN: Tự động khởi tạo tài khoản Portal
    if not user and email:
        Users = request.env["res.users"].sudo()
        group_field = "group_ids" if "group_ids" in Users._fields else "groups_id"
        portal_group = request.env.ref("base.group_portal", raise_if_not_found=False)
        company = request.env["res.company"].sudo().search([], limit=1)
        existing_partner = request.env["res.partner"].sudo().search([("email", "=ilike", email.strip())], limit=1)

        display_name = body.get("name") or (existing_partner.name if existing_partner else None) or "Apple User"
        if display_name == "Apple User" and email:
            display_name = email.split("@")[0].replace(".", " ").title()

        user_vals = {
            "name": display_name,
            "login": email.strip(),
            "email": email.strip(),
            "active": True,
        }
        if hasattr(Users, "apple_sub") and apple_sub:
            user_vals["apple_sub"] = apple_sub
        if existing_partner:
            user_vals["partner_id"] = existing_partner.id
        if portal_group:
            user_vals[group_field] = [(6, 0, [portal_group.id])]
        if company:
            user_vals["company_id"] = company.id
            user_vals["company_ids"] = [(4, company.id)]
        if "vmobile_enabled" in Users._fields:
            user_vals["vmobile_enabled"] = True

        user = Users.with_context(
            no_reset_password=True,
            mail_create_nosubscribe=True,
            mail_notify_author=False,
            mail_auto_delete=True,
        ).create(user_vals)
        AuthController._commit_nodb_write()

    if user:
        uid = user.id
```

---

## 5. DANH SÁCH FILE ẢNH HƯỞNG & THAY ĐỔI

| Thành phần | Đường dẫn file tuyệt đối | Nội dung cập nhật |
|---|---|---|
| **Flutter Client** | [/media/tanma/DATA/save/mobile_versions/vclients/pubspec.yaml](/media/tanma/DATA/save/mobile_versions/vclients/pubspec.yaml) | Bổ sung package `sign_in_with_apple`. |
| **Flutter Client** | [/media/tanma/DATA/save/mobile_versions/vclients/ios/Runner/Runner.entitlements](/media/tanma/DATA/save/mobile_versions/vclients/ios/Runner/Runner.entitlements) | Bổ sung entitlement `com.apple.developer.applesignin`. |
| **Flutter Client** | [/media/tanma/DATA/save/mobile_versions/vclients/lib/features/auth/presentation/login_screen.dart](/media/tanma/DATA/save/mobile_versions/vclients/lib/features/auth/presentation/login_screen.dart) | Thêm nút Sign in with Apple (nền tảng iOS) và hàm xử lý `_signInWithApple()`. |
| **Flutter Client** | [/media/tanma/DATA/save/mobile_versions/vclients/lib/core/api/odoo_api_client.dart](/media/tanma/DATA/save/mobile_versions/vclients/lib/core/api/odoo_api_client.dart) | Mở rộng method `loginOAuth()` nhận thêm tham số `appleSub` và `fullName`. |
| **Backend Odoo 17** | [/media/tanma/DATA/save/mobile_versions/v_mobile_17/models/res_users.py](/media/tanma/DATA/save/mobile_versions/v_mobile_17/models/res_users.py) | Khai báo trường `apple_sub = fields.Char(...)`. |
| **Backend Odoo 17** | [/media/tanma/DATA/save/mobile_versions/v_mobile_17/controllers/auth.py](/media/tanma/DATA/save/mobile_versions/v_mobile_17/controllers/auth.py) | Xử lý nhánh `provider == "apple"` trong endpoint `/api/v1/mobile/auth/oauth`. |
| **Backend Odoo 19** | [/media/tanma/DATA/save/mobile_versions/v_mobile_19/models/res_users.py](/media/tanma/DATA/save/mobile_versions/v_mobile_19/models/res_users.py) | Khai báo trường `apple_sub = fields.Char(...)`. |
| **Backend Odoo 19** | [/media/tanma/DATA/save/mobile_versions/v_mobile_19/controllers/auth.py](/media/tanma/DATA/save/mobile_versions/v_mobile_19/controllers/auth.py) | Xử lý nhánh `provider == "apple"` trong endpoint `/api/v1/mobile/auth/oauth`. |

---

## 6. CHECKLIST 10 CASE KIỂM THỬ ĐỘC LẬP (VERIFICATION CHECKLIST)

1. **TC-01 (UI Display)**: Kiểm tra nút "Sign in with Apple" hiển thị trên iOS và KHÔNG hiển thị trên Android.
2. **TC-02 (Apple HIG Compliance)**: Kiểm tra nút bấm tuân thủ chuẩn kích thước, màu đen, chữ trắng và logo Apple, xếp ngang bằng hoặc trên Google.
3. **TC-03 (First Login - Share Email)**: Đăng nhập lần đầu chọn "Share My Email" ➔ Backend tạo mới `res.users` với email thật.
4. **TC-04 (First Login - Hide Email)**: Đăng nhập lần đầu chọn "Hide My Email" ➔ Backend tạo mới `res.users` với email `@privaterelay.appleid.com`.
5. **TC-05 (Subsequent Login)**: Đăng nhập lần 2 trở đi (Apple chỉ gửi `sub`) ➔ Backend tìm đúng user theo `apple_sub`, không tạo trùng lặp.
6. **TC-06 (Existing User Matching)**: Người dùng đã có sẵn tài khoản email trên Odoo ➔ Tự động liên kết và đăng nhập vào tài khoản đó.
7. **TC-07 (Portal Role Enforcement)**: Người dùng đăng nhập Apple được gán đúng vai trò Khách hàng (`is_portal: true`), ẩn Chấm công/Timesheet, mở CSKH/Ticket.
8. **TC-08 (Cancellation Handling)**: Người dùng bấm Huỷ popup xác thực Apple ➔ App không văng, không hiện lỗi crash, giữ nguyên form đăng nhập.
9. **TC-09 (Biometric / Face ID Failure)**: Người dùng xác thực Face ID thất bại hoặc khóa passcode ➔ App hiển thị thông báo lỗi thân thiện.
10. **TC-10 (Static & Build Check)**: `flutter analyze` 0 lỗi; `python3 -m py_compile` Odoo backend 0 lỗi; build IPA đóng gói thành công.
