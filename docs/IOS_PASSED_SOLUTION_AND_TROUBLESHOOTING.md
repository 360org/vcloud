# TÀI LIỆU QUY TRÌNH KÝ SỐ VÀ XUẤT BẢN iOS TESTFLIGHT THÀNH CÔNG (PASSED SOLUTION)

**Dự án:** VCloud Mobile App (`vclients`)  
**Doanh nghiệp:** W360S JOINT STOCK COMPANY  
**Bundle ID:** `com.w360s.wcloudapp`  
**Team ID:** `ZC3H8887XS`  
**App ID:** `1365622472`  
**Ngày kiểm chứng PASSED thành công 100%:** 13/08/2026  

---

## 1. TỔNG QUAN KẾT QUẢ VÀ TRẠNG THÁI TRÊN APPLE TESTFLIGHT

Tiến trình biên dịch Xcode, Ký số chứng chỉ, Đóng gói IPA và Upload lên Apple TestFlight đã **PASSED THÀNH CÔNG 100%**.

* **Bản build trên App Store Connect:** `v2.4.0 (7)`
* **Trạng thái (Status):** `✔ Complete`
* **Thời gian xuất bản:** 13/08/2026 (12:22 PM)
* **Trạng thái trên iPhone:** Hiển thị nút **UPDATE (Cập nhật)** sẵn sàng kiểm thử.

---

## 2. GIẢI THÍCH VỀ SỐ BUILD `2.4.0 (7)`

Trong file cấu hình [.github/workflows/deploy.yml](file:///media/tanma/DATA/save/mobile/vclients/.github/workflows/deploy.yml), biến `BUILD_NUMBER` được tự động gán bằng:
```yaml
BUILD_NUMBER: ${{ github.run_number }}
```
* **`github.run_number`** là số thứ tự lượt chạy của Workflow trên GitHub Actions.
* Lượt chạy thứ 6 tạo bản build `2.4.0 (6)`.
* Lượt chạy thứ 7 tạo bản build `2.4.0 (7)`.
* Apple App Store Connect tự động nhận diện `2.4.0 (7)` là bản build mới nhất của phiên bản v2.4.0 và phân phối ngay tới ứng dụng TestFlight trên iPhone.

---

## 3. BỘ 3 CHỨNG CHỈ KÝ SỐ XCODE (FIX TRIỆT ĐỂ LỖI ARCHIVING EXIT CODE 65)

Để máy Mac Runner của GitHub luôn luôn có sẵn chứng chỉ ký số (không phụ thuộc API Key từ xa), bộ 3 Secrets sau đây phải luôn được duy trì trên GitHub Secrets (**Settings ➔ Secrets and variables ➔ Actions**):

| Tên Secret trên GitHub | Ý nghĩa & Nguồn file |
| :--- | :--- |
| **`BUILD_CERTIFICATE_BASE64`** | Chuỗi mã hóa Base64 của tệp chứng chỉ `ios_distribution.p12` (Team `ZC3H8887XS`). |
| **`P12_PASSWORD`** | Mật khẩu giải mã file p12: `123456` |
| **`BUILD_PROVISION_PROFILE_BASE64`** | Chuỗi mã hóa Base64 của file `V_cloud.mobileprovision` (UUID: `708b7563-9ec8-4d21-936a-d6edffa66671`). |

### Đã tạo sẵn 2 file Base64 nguồn dưới máy local:
* `mobile/p12_base64.txt` -> Chứa chuỗi mã hóa cho `BUILD_CERTIFICATE_BASE64`
* `mobile/pp_base64.txt` -> Chứa chuỗi mã hóa cho `BUILD_PROVISION_PROFILE_BASE64`

---

## 4. QUY TRÌNH UPLOAD IPA LÊN TESTFLIGHT VIA APP MANAGER (`xcrun altool`)

Để không bị lỗi xác thực `401 NOT_AUTHORIZED` khi API Key `.p8` bị Apple chặn:

1. **Thông số xác thực chính chủ Apple:**
   * **Tài khoản App Manager:** `tanmnn@360.org.vn`
   * **Mật khẩu ứng dụng 16 ký tự:** `yrgq-fslk-lwll-tmas`
   * **Secret GitHub:** `APPLE_ID` và `APPLE_APP_PASS`

2. **Cơ chế dọn rác biến môi trường trong Fastfile:**
   Trước khi chạy lệnh upload `xcrun altool`, Fastlane chủ động xóa sạch các biến rác để `altool` không đọc nhầm token cũ:
   ```ruby
   ENV.delete("APP_STORE_CONNECT_KEY_ID")
   ENV.delete("APP_STORE_CONNECT_ISSUER_ID")
   ENV.delete("APP_STORE_CONNECT_KEY_CONTENT")
   ENV.delete("APP_STORE_CONNECT_KEY_BASE64")

   sh("xcrun altool --upload-app --type ios -f \"#{ipa_path}\" -u \"#{apple_id_email}\" -p \"#{app_pass}\"")
   ```

---

## 5. BẢNG CẤU HÌNH THÔNG SỐ CHUẨN CỦA DỰ ÁN

| Thông số | Giá trị chuẩn |
| :--- | :--- |
| **Bundle Identifier** | `com.w360s.wcloudapp` |
| **Team ID** | `ZC3H8887XS` |
| **Provisioning Profile Name** | `V_cloud` |
| **Signing Style** | Manual |
| **Code Sign Identity** | iPhone Distribution |
| **Export Method** | app-store |

---

*Tài liệu này được lưu trữ vĩnh viễn tại `vclients/docs/IOS_PASSED_SOLUTION_AND_TROUBLESHOOTING.md` để đảm bảo hệ thống CI/CD iOS vận hành mượt mà lâu dài.*
