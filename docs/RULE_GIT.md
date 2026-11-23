# 📘 QUY CHUẨN QUẢN TRỊ GIT, CI/CD & RELEASE (RULE_GIT.md)
> **Phiên bản:** `v3.0.0` — **Áp dụng cho:** Toàn bộ hệ sinh thái **VCloud Mobile (`vclients`)** và **Odoo Backend (`v_mobile`)**  
> **Tiêu chuẩn:** `360-vcloud` & AIaC 2026

---

## 1. 🏛️ KIẾN TRÚC REPOSITORY & NHÁNH CHÍNH (SINGLE SOURCE OF TRUTH)

| Nền tảng / Dự án | Remote Repository | Nhánh Chính Bắt Buộc | Quy Định Merge, Push & Hiển Thị Remote |
| :--- | :--- | :---: | :--- |
| **Frontend Mobile (`vclients`)** | • GitHub: `https://github.com/360org/vcloud`<br>• GitLab: `git@gitlab.com:360org_mobiles/vclients.git` | **`main`** | 🟢 **ĐƯỢC QUYỀN MERGE THẲNG VÀO `main` TRÊN GITHUB (`github/main`)**.<br>Sau khi code & verification pass, AI được phép merge trực tiếp vào `main` và push lên GitHub.<br>⛔ **GitLab ở frontend tuyệt đối KHÔNG cần merge**.<br>CHỈ HIỂN THỊ DUY NHẤT NHÁNH `main` trên GitHub (xóa sạch nhánh rác sau khi merge). |
| **Backend Odoo 19 (`v_mobile_19`)** | • GitLab: `https://gitlab.com/360org_mobiles/v_mobile` | **`19.0`** | 🟢 **ĐƯỢC QUYỀN PUSH THẲNG VÀO `19.0` TRÊN GITLAB (`origin/19.0`)**.<br>Sếp Tân đã ủy quyền: AI được phép push trực tiếp vào `19.0` sau khi test pass. |
| **Backend Odoo 17 (`v_mobile_17`)** | • GitLab: `https://gitlab.com/360org_mobiles/v_mobile` | **`17.0`** | 🟡 **BẮT BUỘC TẠO TASK BRANCH ➔ MERGE VÀO `17.0` TRÊN GITLAB**.<br>Tạo nhánh làm việc (`feat/17-...`, `fix/17-...`), test pass ➔ merge nhánh mới tạo đó vô `17.0`. CẤM push trực tiếp vào `17.0`. |

---

## 2. 🛡️ PHÂN QUYỀN PUSH & MERGE (CẬP NHẬT THEO CHỈ THỊ SẾP TÂN)

* 🟢 **Frontend Mobile (`vclients`)**:
  * AI **có quyền merge thẳng luôn** vào nhánh `main` trên GitHub (`github/main`) sau khi kiểm thử pass.
* 🟢 **Backend Odoo 19 (`v_mobile_19`)**:
  * AI **được quyền push thẳng trực tiếp** vào nhánh `19.0` trên GitLab (`origin/19.0`) sau khi kiểm thử pass.
* 🟡 **Backend Odoo 17 (`v_mobile_17`)**:
  * ❌ **CẤM PUSH TRỰC TIẾP** vào nhánh `17.0`.
  * ✅ **BẮT BUỘC ĐI QUA QUY TRÌNH 4 BƯỚC**:
    ```text
    1. Tạo Task Branch từ HEAD mới nhất của 17.0 (feat/17-... hoặc fix/17-...)
    2. Thực hiện code và kiểm thử (Pass 100% test case)
    3. Merge nhánh mới tạo đó vô nhánh 17.0
    4. Xóa branch tạm sau khi hoàn tất
    ```

---

## 3. 🔢 QUY TẮC ĐẶT TÊN NHÁNH THEO SỐ BUILD TĂNG DẦN (`+1`)

Mỗi khi bắt đầu một đợt phát triển, sửa lỗi hoặc nâng cấp mới, tên nhánh làm việc **BẮT BUỘC** được đặt chuẩn hóa theo số Build của bản dựng và tự động tăng `+1`:

* **Định dạng chuẩn:**
  * Sửa lỗi / Ổn định: `fix/app-build<BUILD_NUMBER>-stabilization`
  * Tính năng mới: `feat/app-build<BUILD_NUMBER>-<feature_name>`
* **Quy luật tịnh tiến số Build (+1):**
  * *Ví dụ:* Đang hoàn tất và merge Build 92 ➔ Task tiếp theo **BẮT BUỘC** tạo nhánh mới là:
    * Frontend: `fix/app-build93-stabilization` (tạo từ đỉnh `main`)
    * Backend: `fix/app-build93-stabilization` (tạo từ đỉnh `17.0`)
  * Khi xong Build 93 ➔ Tạo tiếp `fix/app-build94-stabilization`...
* ❌ **CẤM TÁI SỬ DỤNG NHÁNH CŨ**: Tuyệt đối không commit tiếp vào các nhánh của build cũ đã merge xong.

---

## 4. 🧹 QUY TRÌNH XÓA NHÁNH SAU KHI MERGE (RULE XÓA SẠCH)

Sau khi một Pull Request (GitHub) hoặc Merge Request (GitLab) đã được merge thành công vào `main` hoặc `17.0`:

1. **Xóa ngay lập tức nhánh trên Remote:**
   ```bash
   # Xóa trên GitLab (origin)
   git push origin --delete <tên_nhánh>

   # Xóa trên GitHub (github)
   git push github --delete <tên_nhánh>
   ```
2. **Xóa ngay lập tức nhánh ở Local:**
   ```bash
   git branch -D <tên_nhánh>
   ```
3. **Mục tiêu:** Đảm bảo trên giao diện GitHub (`https://github.com/360org/vcloud`) **chỉ hiển thị duy nhất nhánh `main`**, không lưu lại các nhánh rác đã qua sử dụng.

---

## 5. ⚙️ CẤU HÌNH GITHUB ACTIONS CI/CD (TESTFLIGHT DEPLOYMENT)

* 🟢 **CHỈ DUY NHẤT NHÁNH `main` MỚI ĐƯỢC CHẠY GITHUB ACTIONS**:
  * Khi Pull Request được merge vào `main` ➔ GitHub Actions (`deploy.yml`) sẽ tự động kích hoạt tiến trình Build & Deploy TestFlight cho iOS.
* 🔴 **BỎ TOÀN BỘ ACTION TRÊN CÁC NHÁNH KHÁC**:
  * Nhánh `release/ios-appstore`, `release/*` **KHÔNG** còn được kích hoạt action tự động.
* 🔴 **TAG & RELEASE TUYỆT ĐỐI KHÔNG TỰ ĐỘNG CHẠY ACTION**:
  * File `.github/workflows/deploy.yml` **ĐÃ BỎ trigger `tags: - "v*"`**.
  * Việc tạo Tag hoặc Release thủ công hay tự động qua Git/GitHub sẽ **KHÔNG làm kích hoạt chạy action ngoài ý muốn**, giúp anh Tân kiểm soát 100% thời điểm build bản dựng.
* 🕹️ **Kích hoạt thủ công:** Vẫn hỗ trợ trigger qua `workflow_dispatch` trên giao diện GitHub Actions khi anh Tân muốn build chủ động.

---

## 6. 🏷️ QUY TRÌNH TẠO RELEASE, TAG & BÁO CÁO AUDIT KỸ THUẬT

Mỗi khi hoàn thành merge một bản Build vào `main` của Frontend:

1. **Tạo Git Tag chuẩn:**
   ```bash
   git tag -a -f vX.Y.Z+<BUILD> -m "Release vX.Y.Z+<BUILD>" <commit_hash_tren_main>
   git push origin refs/tags/vX.Y.Z+<BUILD> --force
   git push github refs/tags/vX.Y.Z+<BUILD> --force
   ```
2. **Tạo GitHub / GitLab Release:**
   * **Tiêu đề:** `Release vX.Y.Z (Build <BUILD>)`
   * **Target:** Trỏ trực tiếp vào Tag `vX.Y.Z+<BUILD>` trên `main`.
   * **Release Body:** Nhúng toàn bộ nội dung file `docs/AUDIT_REPORT.md` (Báo cáo audit kỹ thuật chi tiết 5 trụ cột).

---

## 7. 📜 QUY TẮC QUẢN TRỊ CHANGELOG & CHỐNG LẠM PHÁT VERSION (ANTI-INFLATION)

> [!CAUTION]
> **ĐANG Ở VERSION NÀO THÌ TIẾP TỤC GHI NHẬN Ở VERSION ĐÓ. TUYỆT ĐỐI KHÔNG TỰ Ý TĂNG VERSION KHI CHƯA HOÀN TẤT & DEPLOY!**

1. **Nguyên tắc bám sát Version thực tế**:
   * Khi đang làm việc trên branch của một Build (ví dụ: `fix/app-build92-stabilization`), toàn bộ các tính năng, bug fix, refactor và cập nhật tài liệu **BẮT BUỘC chỉ được ghi trong mục của version hiện tại** (VD: `## [v2.5.0+92] — YYYY-MM-DD`).
2. **Chống lạm phát Version (Zero Version Inflation)**:
   * **TUYỆT ĐỐI KHÔNG TỰ Ý TẠO MỤC VERSION MỚI** trong `CHANGELOGS.md` khi phiên bản hiện tại chưa được deploy TestFlight, chưa được anh Tân kiểm tra thực tế trên iPhone 13, và chưa merge/xóa nhánh.
   * *Nghiêm cấm:* Phiên bản đang chạy trên thiết bị là Build 90 mà trong code tự ý tạo và nhảy cóc version lên Build 95, 96, 97 trong cùng một đợt làm việc.
3. **Mỗi khi cập nhật `CHANGELOGS.md`**:
   * AI và Developer **BẮT BUỘC PHẢI ĐỌC LẠI `RULE_GIT.md`** để đảm bảo số version trong `pubspec.yaml`, `CHANGELOGS.md`, `__manifest__.py` và tên nhánh hoàn toàn trùng khớp $1:1$.

---
*Quy chuẩn này là LUẬT CỨNG BẮT BUỘC, có hiệu lực ngay lập tức cho toàn bộ các phiên làm việc tiếp theo.*
