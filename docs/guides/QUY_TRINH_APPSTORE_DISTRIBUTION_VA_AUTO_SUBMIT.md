# Quy Trình Tự Động Hóa App Store Distribution & Auto-Submit Cho VCloud iOS

Tài liệu hướng dẫn quy trình đưa ứng dụng Vcloud từ TestFlight sang trang Distribution của App Store Connect và tự động gửi duyệt (Submit for Apple Review) hoàn toàn qua REST API.

---

## 1. Bối Cảnh & Vấn Đề Giải Quyết
- **Bình thường qua CI/CD Fastlane**: Binary IPA được upload lên Apple qua `altool`/`upload_to_testflight`. Khi Apple xử lý xong, bản build chỉ xuất hiện tại tab **TestFlight**.
- **Yêu cầu App Store Distribution**: Để người dùng tải được trên App Store, ứng dụng bắt buộc phải:
  1. Có một thực thể phiên bản (`appStoreVersions`) ở trạng thái chuẩn bị (`PREPARE_FOR_SUBMISSION`).
  2. Gắn (attach) bản dựng `builds` đã sẵn sàng từ TestFlight vào phiên bản đó.
  3. Cập nhật nội dung mô tả phiên bản (`whatsNew` / Release Notes).
  4. Tạo đợt duyệt (`reviewSubmissions`), thêm item và nhấn gửi duyệt (`submitted: true`).
- **Tool tự động hóa**: Script `scripts/appstore_distribute_and_submit.py` tự động hóa 100% các bước trên mà không cần thao tác thủ công trên giao diện web App Store Connect.

---

## 2. Thông Tin Cấu Hình & Xác Thực

- **App ID (Apple ID)**: `1365622472` (`com.w360s.wcloudapp`)
- **Key ID**: `3J68D9JX79` (Team Key với đầy đủ quyền App Manager)
- **Issuer ID**: `69a6de93-488c-47e3-e053-5b8c7c11a4d1`
- **Tệp khóa bảo mật**: `/media/tanma/DATA/save/file_ios_p8/AuthKey_3J68D9JX79.p8`
- **Thuật toán chữ ký**: `ES256` (JWT token thời hạn 20 phút)

---

## 3. Kiến Trúc Luồng Hoạt Động (5 Bước)

```text
[pubspec.yaml (SSOT)] ➔ Version & Build Number (VD: 2.9.22+167)
          │
          ▼
[Bước 1: Kết nối REST API] ➔ Tạo JWT ES256 từ AuthKey_3J68D9JX79.p8
          │
          ▼
[Bước 2: Quản lý Phiên Bản] ➔ GET /apps/{id}/appStoreVersions
  ├─ Nếu đã có phiên bản target ➔ Lấy version ID
  ├─ Nếu có bản draft cũ ➔ PATCH đổi versionString sang bản mới
  └─ Nếu chưa có ➔ POST /appStoreVersions tạo mới (IOS)
          │
          ▼
[Bước 3: Gắn Build TestFlight]
  ├─ GET /builds (Lọc theo build number & processingState == VALID)
  └─ PATCH /appStoreVersions/{versionId}/relationships/build
          │
          ▼
[Bước 4: Cập Nhật Release Notes]
  ├─ Đọc tự động từ docs/CHANGELOGS.md
  └─ PATCH /appStoreVersionLocalizations (Đồng bộ ngôn ngữ vi & en-US)
          │
          ▼
[Bước 5: Gửi Duyệt Tự Động (Review Submissions API)]
  ├─ POST /reviewSubmissions (Khởi tạo đợt duyệt mới)
  ├─ POST /reviewSubmissionItems (Gắn version vào đợt duyệt)
  └─ PATCH /reviewSubmissions/{id} (Gửi duyệt: submitted = true) ➔ 🟡 WAITING_FOR_REVIEW
```

---

## 4. Cách Sử Dụng Lệnh Tái Sử Dụng

Script nằm tại: `vclients/scripts/appstore_distribute_and_submit.py`.

### 1. Chạy Tự Động Hoàn Toàn (Khuyên dùng)
Tự động đọc phiên bản và số build từ `pubspec.yaml`, đọc ghi chú từ `CHANGELOGS.md`, tạo version, gán build và gửi duyệt luôn:
```bash
python3 scripts/appstore_distribute_and_submit.py
```

### 2. Chỉ định phiên bản & build cụ thể
```bash
python3 scripts/appstore_distribute_and_submit.py --version 2.9.23 --build 168
```

### 3. Chỉ đưa lên Distribution và gán build, CHƯA gửi duyệt (giữ bản nháp)
```bash
python3 scripts/appstore_distribute_and_submit.py --no-submit
```

### 4. Tùy biến nội dung ghi chú phát hành (What's New)
```bash
python3 scripts/appstore_distribute_and_submit.py --notes "Tối ưu tính năng gọi điện CallKit và fix lỗi thông báo nền."
```

### 5. Tự Động Hóa 100% Trong GitHub Actions CI/CD (`.github/workflows/deploy.yml`)
Quy trình đã được tích hợp trực tiếp vào job `build-ios-testflight`:
- Sau khi Fastlane upload IPA lên Apple, step `Auto-Distribute to App Store & Submit for Review` sẽ tự động thực thi.
- Sử dụng trực tiếp `APP_STORE_CONNECT_KEY_CONTENT` từ GitHub Secrets.
- Cơ chế tự động đợi (`polling`) tối đa 10 phút đến khi bản build chuyển sang trạng thái `VALID`.
- Tự động tạo bản phát hành trên tab Distribution, gán build và gửi Apple xét duyệt ngay lập tức (không cần can thiệp thủ công).

---

## 6. Xử Lý Sự Cố Thường Gặp

| Hiện tượng | Nguyên nhân | Cách khắc phục |
|---|---|---|
| `Build not found / INVALID` | Apple chưa xử lý xong binary nạp lên | Chờ 3-5 phút để Apple hoàn tất TestFlight processing (State = VALID) rồi chạy lại. |
| `HTTP 401 Unauthorized` | Key .p8 bị sai đường dẫn hoặc hết hạn | Kiểm tra file `/media/tanma/DATA/save/file_ios_p8/AuthKey_3J68D9JX79.p8`. |
| `State already WAITING_FOR_REVIEW` | Bản dựng đã gửi duyệt trước đó | Kiểm tra trên App Store Connect, phiên bản đang chờ Apple review không cần gửi lại. |
| `There is already an active submission` | Có đợt duyệt cũ chưa hoàn tất | Script tự động phát hiện `READY_FOR_REVIEW` hoặc tạo submission mới. |

---

*Tài liệu được khởi tạo và kiểm chứng thực tế cùng đợt phát hành `v2.9.22+167` thành công.*
*Trailer: Authored-By: 360org <support@360.org.vn>*
