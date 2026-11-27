# 🛑 CLAUDE CODE EXECUTION CONTRACT: MOBILE CI/CD RELEASE & STORE DEPLOYMENT ENGINE (prompt_deploy_mobile_release.md)
# Director: Sếp Tân | Phase: /ship & /release | Version: Agent OS v3.1 Protocol
# SSOT: vclients/docs/guides/AUTO_DEPLOY_MOBILE . md & error_mobile . md & git . md & vclients/.github/workflows/deploy . yml
# Kích hoạt: Khi Sếp Tân ra lệnh "deploy mobile", "deploy store", "chay deploy mobile", "prompt_deploy_mobile_release.md"

================================================================================
🏛️ [TRỤ CỘT 1: 👤 MULTI-AGENT TEAM DELEGATION MATRIX & DISPATCH DIRECTIVE]
🚨 PHÂN CÔNG QUYỀN HẠN ĐỘC QUYỀN & CHỈ THỊ ĐIỀU PHỐI (1-FILE-1-OWNER):
- `@lead`: Team Lead Orchestrator (tiếp nhận chỉ đạo của Sếp Tân, cắm lock `.claude/agent_state/task_locks . yaml`, kiểm soát radar remote, trực tiếp điều phối baton và giám sát vòng lặp CI/CD Watch Loop, xuất Báo cáo Nghiệm thu Release Bảng < 1.200 ký tự).
  ⛔ **CẤM TUYỆT ĐỐI**: Không được ngắt phiên giữa chừng khi GitHub Actions còn đang chạy (`in_progress`/`queued`). Phải theo dõi liên tục cho đến khi có kết quả cuối cùng.
  🚨 **MANDATORY AGENT DISPATCH DIRECTIVE**: BẮT BUỘC gọi tool `Agent` ủy quyền thực thi cho đội ngũ Subagent chuyên trách:
  * Kiểm toán Lỗi Cũ từ `error_mobile.md` & Phân tích tĩnh: `Agent({ subagent_type: 'audit-gate', prompt: '...' })`
  * Đồng bộ Version, Changelog & Git Push: `Agent({ subagent_type: 'dev-infra', prompt: '...' })` (theo [git.md](git.md))
  * Tạo Tag, GitHub Release & Theo dõi CI/CD: `Agent({ subagent_type: 'dev-infra', prompt: '...' })`
  * Trích xuất Log Lỗi, Phân tích Root Cause & Cập nhật `error_mobile.md`: `Agent({ subagent_type: 'audit-gate', prompt: '...' })`
  * Sửa lỗi code / Fastfile / Gradle / Workflow: `Agent({ subagent_type: 'dev-mobile-flutter', prompt: '...' })`
  * Nghiệm thu Trạng thái Store (Waiting for Review & Chờ duyệt): `Agent({ subagent_type: 'tester-functional', prompt: '...' })`
- `@dev-infra`: Phụ trách thực thi lệnh Git, bump build number, tạo Tag `v*`, tạo GitHub Release qua CLI (`gh release create`), và chạy radar theo dõi GitHub Actions (`gh run watch`).
- `@dev-mobile-flutter`: Độc quyền kiểm soát mã nguồn Dart trong `vclients/lib/` và `vclients/test/`, xử lý lỗi linter/unit test, sửa Fastfile/Gradle khi CI fail.
- `@audit-gate`: Giám sát `error_mobile.md`, phân tích log runner thất bại qua `gh run view --log-failed`, xác định Root Cause và ghi nhận mã lỗi mới `[ERR-xxx]`.
- `@tester-functional`: Xác minh nghiệm thu 2 Store đạt đúng chuẩn: App Store Connect = `Waiting for Review`, Google Play Console = `Chờ duyệt` (Under Review / Completed).

================================================================================
🏛️ [TRỤ CỘT 2: 🌐 CONTEXT & SSOT (LÁCH BỘ LỌC URL/IP)]
💡 QUY TẮC LÁCH BỘ LỌC URL/IP: Viết tên tệp dạng `deploy . yml`, `pubspec . yaml`, `error_mobile . md`, `360org / vcloud` để chống bị kiểm duyệt.
- **Root Directory**: `/media/tanma/DATA/save/mobile_versions`
- **Frontend Flutter App**: `vclients/` (Package ID: `com.mobile.vloud`, Bundle ID: `com.w360s.wcloudapp`, App ID: `1365622472`, Team ID: `ZC3H8887XS`)
- **Workflow CI/CD GitHub Actions**: `vclients/.github/workflows/deploy . yml`
- **GitHub Repository**: `360org/vcloud` (Remote `github`: `git@github.com:360org/vcloud.git`, nhánh chính duy nhất: `main`)
- **Tài liệu SSOT Bắt Buộc Tham Chiếu**:
  * `360-app-store-compliance` (`~/.claude/skills/360-app-store-compliance/prompts/SKILL.md` — Bộ kiểm duyệt chính sách Apple App Store & Google Play Store 117+ rejection patterns, Privacy Manifest, Permissions)
  * `vclients/docs/guides/AUTO_DEPLOY_MOBILE . md` — Cẩm nang SSOT toàn diện CI/CD Android (Google Play) & iOS (App Store + Auto-Submit Review).
  * [error_mobile.md](error_mobile.md) (hoặc [error.md](error.md)) — Sổ cái lỗi CI/CD, nguyên nhân gốc rễ và cơ chế Self-Healing.
  * [git.md](git.md) — Quy chuẩn quản trị Git, chống đè code, chỉ push/merge nhánh `main` ở GitHub cho frontend.
  * `vclients/fastlane/Fastfile` — Lane `android beta` (AAB Play Store) và `ios beta` (IPA TestFlight + App Store).
  * `vclients/scripts/appstore_distribute_and_submit . py` — Script tự động tạo version, gán build và submit Apple review.

================================================================================
🧰 [SKILLS AIAC BẮT BUỘC]
Nạp: `360-dev-workflow`, `360-flutter`, `360-vcloud`, `360-app-store-compliance`, `audit-gate`, `code-review`.
* Bắt buộc chạy **`360-app-store-compliance`** (`compliance-guard.sh` + `metadata-audit.py`) VÀ `/ponytail-audit` trước mọi đợt chốt release lên GitHub Actions.

================================================================================
🔄 SƠ ĐỒ VÒNG LẶP TỰ ĐỘNG PHÁT HÀNH & TỰ CHỮA LỖI (CLOSED SELF-HEALING LOOP)

```text
 ┌────────────────────────────────────────────────────────────────────────┐
 │ 🛡️ CỔNG 0: ĐỌC error_mobile.md & CHẠY 360-app-store-compliance AUDIT   │
 └───────────────────────────────────┬────────────────────────────────────┘
                                     │
                                     ▼
 ┌────────────────────────────────────────────────────────────────────────┐
 │ 🛡️ CỔNG 1: ĐỒNG BỘ REMOTE THEO git.md (vcloud-sync check / SAFE PULL)  │
 └───────────────────────────────────┬────────────────────────────────────┘
                                     │
                                     ▼
 ┌────────────────────────────────────────────────────────────────────────┐
 │ 📦 CỔNG 2: TĂNG BUILD NUMBER (+1) TRONG pubspec.yaml & CẬP NHẬT DOCS   │
 └───────────────────────────────────┬────────────────────────────────────┘
                                     │
                                     ▼
 ┌────────────────────────────────────────────────────────────────────────┐
 │ 🚀 CỔNG 3: COMMIT & PUSH FULL CODE LÊN GITHUB MAIN (KÈM TRAILER CHUẨN) │
 └───────────────────────────────────┬────────────────────────────────────┘
                                     │
                                     ▼
 ┌────────────────────────────────────────────────────────────────────────┐
 │ 🏷️ CỔNG 4: TẠO GIT TAG CHUẨN (vX.Y.Z+<BUILD>) & PUSH TAG LÊN GITHUB    │
 └───────────────────────────────────┬────────────────────────────────────┘
                                     │
                                     ▼
 ┌────────────────────────────────────────────────────────────────────────┐
 │ 📢 CỔNG 5: TẠO GITHUB RELEASE (KÍCH HOẠT deploy.yml CI/CD TỰ ĐỘNG)     │
 └───────────────────────────────────┬────────────────────────────────────┘
                                     │
                                     ▼
 ┌────────────────────────────────────────────────────────────────────────┐
 │ 🛰️ CỔNG 6: THEO DÕI RUNNER ĐẾN KHI NÀO XONG THÌ THÔI (WATCH LOOP)     │
 │             (gh run watch <run_id> --interval 30)                      │
 └───────────────────────────────────┬────────────────────────────────────┘
                                     │
                       Kiểm tra kết quả (.conclusion)
                                     │
               ┌─────────────────────┴─────────────────────┐
               │                                           │
         THÀNH CÔNG (success)                       THẤT BẠI (failure)
               │                                           │
               ▼                                           ▼
 ┌───────────────────────────┐               ┌───────────────────────────┐
 │ 🏁 CỔNG 8: NGHIỆM THU     │               │ 🩹 CỔNG 7: TỰ CHỮA LỖI    │
 │    1. App Store Connect:  │               │ 1. Trích xuất log lỗi     │
 │       Waiting for Review  │               │ 2. Cập nhật error_mobile  │
 │    2. Google Play Console:│               │ 3. Sửa code / config      │
 │       Chờ duyệt (Review)  │               │ 4. Tăng Build (+1)        │
 │    3. Bàn giao Sếp Tân    │               │ 5. Commit & Re-Release    │
 └───────────────────────────┘               └─────────────┬─────────────┘
                                                           │
                                                           ▼
                                             (LẶP LẠI CHO ĐẾN KHI THÀNH CÔNG)
```

================================================================================
🏛️ [TRỤ CỘT 3: 📋 TASK DETAILS — QUY TRÌNH 8 CỔNG AN TOÀN TUYỆT ĐỐI]

#### 📋 MANDATORY INTERACTIVE TODO CHECKLIST GATE (TodoWrite — BẮT BUỘC KHỞI TẠO ĐẦU PHIÊN):
Agent BẮT BUỘC khởi tạo và cập nhật Interactive Todo Checklist thông qua tool `TodoWrite` ngay từ bước đầu tiên:
0. `[pending]` Gate 0: Đọc [error_mobile.md](error_mobile.md) (ERR-001..ERR-013+), chạy audit chính sách Store theo skill AIaC **`360-app-store-compliance`** (`compliance-guard.sh` + `metadata-audit.py`), kiểm tra `flutter analyze --no-fatal-infos` 0 lỗi.
1. `[pending]` Gate 1: Kiểm tra trạng thái Git trên GitHub theo [git.md](git.md) (`vcloud-sync check`).
2. `[pending]` Gate 2: Tăng Build Number (+1) trong `pubspec.yaml`, cập nhật `docs/CHANGELOGS.md`.
3. `[pending]` Gate 3: Commit & Push đầy đủ code lên `github/main` kèm trailer `Authored-By: 360org <support@360.org.vn>`.
4. `[pending]` Gate 4: Tạo Git Tag `vX.Y.Z+<BUILD>` và push tag lên GitHub.
5. `[pending]` Gate 5: Tạo GitHub Release qua CLI (`gh release create`) để kích hoạt `deploy.yml`.
6. `[pending]` Gate 6: Theo dõi log GitHub Actions (`gh run watch`) ĐẾN KHI NÀO XONG THÌ THÔI.
7. `[pending]` Gate 7: Self-Healing nếu có lỗi (trích xuất log ➔ cập nhật [error_mobile.md](error_mobile.md) ➔ fix code ➔ tăng build +1 ➔ chạy lại đến khi thành công).
8. `[pending]` Gate 8: Nghiệm thu hoàn thành khi App Store = Waiting for Review và Google Play = Chờ duyệt. Xuất Báo cáo (< 1.200 ký tự) cho Sếp Tân.

---

### 🛡️ GATE 0: PRE-FLIGHT ERROR & APP STORE POLICY COMPLIANCE AUDIT (`error_mobile.md` + `360-app-store-compliance`)
Trước khi tạo Release hoặc đẩy code lên GitHub Actions (`deploy.yml`), Agent **BẮT BUỘC THỰC HIỆN ĐỦ 2 PHẦN**:

1. **Chạy Audit Chính sách Mobile Store bằng Skill AIaC `360-app-store-compliance`** (`~/.claude/skills/360-app-store-compliance/prompts/SKILL.md`):
   ```bash
   # Linux / macOS:
   bash ~/.claude/skills/360-app-store-compliance/scripts/compliance-guard.sh "/đường/dẫn/tới/vclients"
   # Windows (qua Git Bash):
   "C:\Program Files\Git\bin\bash.exe" "$HOME/.claude/skills/360-app-store-compliance/scripts/compliance-guard.sh" "/đường/dẫn/tới/vclients"

   # Quét Metadata Store & Privacy Manifest (nếu có):
   python3 ~/.claude/skills/360-app-store-compliance/scripts/metadata-audit.py "/đường/dẫn/tới/vclients/fastlane/metadata"
   python3 ~/.claude/skills/360-app-store-compliance/scripts/validate-privacy-manifest.py "/đường/dẫn/tới/vclients/ios/Runner/PrivacyInfo.xcprivacy"
   ```
   - **Quy tắc chặn Release:** Nếu `compliance-guard.sh` trả về `[CRITICAL]` thật (exit code `2`) — đặc biệt các lỗi:
     * Thiếu `ios/Runner/PrivacyInfo.xcprivacy` (`FLUTTER-PRIVACY-MANIFEST-MISSING`)
     * Thiếu luồng **Xóa tài khoản trong app** nếu có đăng ký tài khoản (`APPLE-5.1.1-NO-ACCOUNT-DELETION` — Guideline 5.1.1(v))
     * Thiếu link Privacy Policy công khai trong app & Store listing (`APPLE-5.1.1-MISSING-PRIVACY-POLICY` / `GOOGLE-MISSING-PRIVACY-POLICY`)
     * Code release trỏ URL staging/localhost (`APPLE-2.1-STAGING-BACKEND`)
     * `Info.plist` khai báo quyền hoặc `UIBackgroundModes` (`voip`, `audio`, microphone...) nhưng giao diện đang ẩn tính năng đó mà Reviewer kiểm tra thấy không dùng tới
     * Android manifest khai báo quyền nhạy cảm chưa giải trình (`SYSTEM_ALERT_WINDOW`, `READ_MEDIA_IMAGES` / `READ_MEDIA_VIDEO`) hoặc thiếu R8 minify
     ➔ **BẮT BUỘC BÁO CÁO ANH TÂN ĐỂ XỬ LÝ / XÁC NHẬN TRƯỚC KHI ĐẨY RELEASE** (không tự ý bypass `APP_STORE_GUARD_OK=1`).

2. **Đọc sổ cái [error_mobile.md](error_mobile.md)** và đối soát các lỗi kinh điển (`ERR-001` ➔ `ERR-013+`):
- [ ] **ERR-001 (Fastlane Locales)**: Mã ngôn ngữ Tiếng Việt trong Fastfile BẮT BUỘC là `"vi"`, cấm dùng `"vi-VN"` hay `"default"`.
- [ ] **ERR-002 (Changelog Length)**: Độ dài nội dung "Có gì mới" khống chế an toàn `<= 480 ký tự`, lọc sạch markdown (`*`, `, `>`).
- [ ] **ERR-003 (Build Number SSOT)**: Build number hiển thị Store phải lấy từ `pubspec.yaml` làm nguồn chân lý duy nhất.
- [ ] **ERR-004 (Dart Linter `unawaited_return`)**: Chạy `flutter analyze` đạt 0 errors, 0 warnings; không có hàm `async` nào return Future trong `try` thiếu `await`.
- [ ] **ERR-005 (Apple Release Train 90186)**: Nếu train version cũ bị Apple đóng, bắt buộc bump Marketing Version (`2.9.32` ➔ `2.9.33`) thay vì chỉ tăng mỗi build number.
- [ ] **ERR-006 (Step Guard)**: Bước `Auto-Distribute to App Store` trong `deploy.yml` phải giữ `continue-on-error: true` để tránh fail oan khi Apple delay `PROCESSING`.
- [ ] **ERR-007 (Desugaring)**: `build.gradle.kts` đã bật `isCoreLibraryDesugaringEnabled = true`.
- [ ] **ERR-008 (AAB Path)**: Fastlane candidate paths dùng `File.expand_path` đa ứng viên.
- [ ] **ERR-009 (Tag Collision)**: Tag mới không được trùng lặp với bất kỳ tag nào đã tồn tại trên remote.
- [ ] **ERR-010 (Branch Rule)**: Nhánh duy nhất của Frontend là **`main`**. Cấm dùng nhánh rác cũ `release/ios-appstore`.
- [ ] **ERR-011 / ERR-012**: Không hardcode `'db'` vào master auth khi trỏ prod và ghim `flutter-version: "3.44.7"` kèm `--no-fatal-infos`.
- [ ] **ERR-013 (Apple Business Agreement)**: Nhắc/kiểm tra tài khoản Apple Developer đã ký thỏa thuận mới tại `https://appstoreconnect.apple.com/business` trước khi chạy lane iOS TestFlight (`403 REQUIRED_AGREEMENTS_MISSING_OR_EXPIRED`).

---

### 🛡️ GATE 1: REMOTE SYNC & CONFLICT GUARD (THEO CHUẨN git . md)
1. Kiểm tra trạng thái đồng bộ remote:
   ```bash
   cd /media/tanma/DATA/save/mobile_versions/vclients
   git fetch github main --prune
   git status -uno
   ```
2. Nếu remote có commit mới (`behind > 0`):
   ```bash
   git stash save "wip_before_release_$(date +%Y%m%d_%H%M%S)"
   git pull --rebase github main
   git stash pop || true
   ```
3. Chạy kiểm tra tĩnh đảm bảo mã nguồn biên dịch sạch:
   ```bash
   flutter analyze
   ```

---

### 📦 GATE 2: TĂNG SỐ BUILD NUMBER (+1) & ĐỒNG BỘ TÀI LIỆU
1. **Đọc version hiện tại trong `vclients/pubspec.yaml`**:
   * Kiểm tra dòng `version: X.Y.Z+BUILD` (VD: `2.9.32+185`).
2. **Tăng số Build Number (+1)**:
   * Nếu giữ Marketing Version: tăng `+1` build number (VD: `2.9.32+186`).
   * Nếu mở Release Train mới: tăng version (VD: `2.9.33+186`).
   * Sửa trực tiếp trong `vclients/pubspec.yaml`.
3. **Đồng bộ mục phiên bản mới trong `docs/CHANGELOGS . md`**:
   * Ghi nhận ngày phát hành `(YYYY-MM-DD)` và các tính năng/sửa lỗi mới kèm tag chuẩn `[NEW]`, `[FIX]`, `[IMPROVE]`.
   * Khống chế phần tóm tắt dưới 480 ký tự để Fastlane tự động trích xuất cho Store metadata.

---

### 🚀 GATE 3: COMMIT & PUSH FULL CODE LÊN GITHUB MAIN
```bash
cd /media/tanma/DATA/save/mobile_versions/vclients
git add pubspec.yaml ../docs/CHANGELOGS.md ../docs/features.md .claude/
git commit -m "chore(release): bump version to $(grep -E '^version:' pubspec.yaml | awk '{print $2}')

Authored-By: 360org <support@360.org.vn>"

git push github main
```

---

### 🏷️ GATE 4: TẠO GIT TAG CHUẨN & PUSH LÊN GITHUB
1. Trích xuất tên tag chuẩn từ `pubspec.yaml`:
   ```bash
   cd /media/tanma/DATA/save/mobile_versions/vclients
   TAG_VERSION="v$(grep -E '^version:' pubspec.yaml | awk '{print $2}')"
   echo "Tag chuẩn bị tạo: ${TAG_VERSION}"
   ```
2. Kiểm tra tag xem đã tồn tại trên GitHub chưa (chống lỗi `ERR-009`):
   ```bash
   if git ls-remote --tags github | grep -q "refs/tags/${TAG_VERSION}$"; then
       echo "❌ Lỗi: Tag ${TAG_VERSION} đã tồn tại trên GitHub! Phải tăng Build Number trước."
       exit 1
   fi
   ```
3. Tạo annotated tag cục bộ và đẩy lên remote `github`:
   ```bash
   git tag -a -f "${TAG_VERSION}" -m "Release ${TAG_VERSION}" HEAD
   git push github refs/tags/"${TAG_VERSION}" --force
   echo "✅ Đã đẩy Tag ${TAG_VERSION} lên GitHub thành công!"
   ```

---

### 📢 GATE 5: TẠO GITHUB RELEASE QUA CLI (KÍCH HOẠT deploy.yml TỰ ĐỘNG)
Kích hoạt GitHub Actions tự động thông qua sự kiện `release: published`:
```bash
cd /media/tanma/DATA/save/mobile_versions/vclients
TAG_VERSION="v$(grep -E '^version:' pubspec.yaml | awk '{print $2}')"

gh release create "${TAG_VERSION}" \
  --repo 360org/vcloud \
  --title "Release ${TAG_VERSION}" \
  --notes "Bản phát hành tự động ${TAG_VERSION} được phân phối qua CI/CD lên Apple App Store (Waiting for Review) và Google Play Console (Production Track).

Commit: $(git rev-parse --short HEAD) trên nhánh main.
Được kích hoạt bởi hệ thống AIaC Release Engine v3.1."
```
*Ngay khi câu lệnh thực thi, GitHub Actions sẽ lập tức khởi chạy song song 2 job:*
- `build-android-release`: Build AAB & Upload Google Play Production.
- `build-ios-testflight`: Build IPA ➔ Upload TestFlight ➔ Auto-Distribute App Store & Submit Review.

---

### 🛰️ GATE 6: RADAR THEO DÕI GITHUB ACTIONS ĐẾN KHI XONG THÌ THÔI (MANDATORY WATCH LOOP)
🚨 **YÊU CẦU BẮT BUỘC ĐỐI VỚI AGENT**:
- Agent **TUYỆT ĐỐI KHÔNG ĐƯỢC DỪNG PHIÊN** khi workflow còn đang chạy (`in_progress` hoặc `queued`).
- BẮT BUỘC theo dõi liên tục cho đến khi có kết quả cuối cùng (Conclusion là `success` hoặc `failure`).

```bash
# 1. Chờ 15s để GitHub khởi tạo run ID
sleep 15
RUN_ID=$(gh run list --repo 360org/vcloud --workflow=deploy.yml --limit=1 --json databaseId -q '.[0].databaseId')
echo "======================================================="
echo "🛰️ ĐANG THEO DÕI GITHUB ACTIONS RUN ID: ${RUN_ID}"
echo "🔗 URL: https://github.com/360org/vcloud/actions/runs/${RUN_ID}"
echo "======================================================="

# 2. Theo dõi liên tục bằng lệnh gh run watch
gh run watch "${RUN_ID}" --repo 360org/vcloud --interval 30

# 3. Kiểm tra kết luận cuối cùng
CONCLUSION=$(gh run view "${RUN_ID}" --repo 360org/vcloud --json conclusion -q '.conclusion')
echo "Kết quả cuối cùng của Workflow: ${CONCLUSION}"
```
* **Nếu `${CONCLUSION} == "success"`**: Chuyển sang **Gate 8** để kiểm tra nghiệm thu Store.
* **Nếu `${CONCLUSION} == "failure"` hoặc `"cancelled"`**: Chuyển ngay sang **Gate 7 (Self-Healing Loop)**.

---

### 🩹 GATE 7: QUY TRÌNH TỰ ĐỘNG SỬA LỖI & CHẠY LẠI ĐẾN KHI THÀNH CÔNG (SELF-HEALING LOOP)
Khi phát hiện GitHub Actions bị **FAILED (ĐỎ)**, Agent BẮT BUỘC thực thi tuần tự:
1. **Trích xuất log lỗi chi tiết từ runner**:
   ```bash
   gh run view "${RUN_ID}" --repo 360org/vcloud --log-failed > /tmp/ci_failed_log.txt
   tail -n 60 /tmp/ci_failed_log.txt
   ```
2. **Phân tích Root Cause & Cập nhật `error_mobile.md`**:
   - Xác định nguyên nhân: Linter fail? Unit test fail? Fastlane supply fail? Trùng build number? Apple đóng release train?
   - Thêm mã lỗi mới `[ERR-xxx]` vào `error_mobile.md` kèm giải pháp.
3. **Sửa trực tiếp lỗi trong mã nguồn / cấu hình**:
   - Sửa file code Dart, `Fastfile`, `build.gradle.kts` hoặc workflow `deploy.yml`.
   - Chạy `flutter analyze` tại local xác nhận 0 lỗi.
4. **Tăng tiếp số Build Number (+1)**:
   - Sửa `vclients/pubspec.yaml`: tăng Build Number lên tiếp `+1` (VD: `186` ➔ `187`).
   - Nếu Apple đóng train: bump cả Marketing Version (`2.9.33` ➔ `2.9.34`).
   - Cập nhật lại `docs/CHANGELOGS.md`.
5. **Commit, Push, Tạo Tag & Release mới**:
   ```bash
   git add -A
   git commit -m "fix(ci): fix error & bump build to $(grep -E '^version:' pubspec.yaml | awk '{print $2}')

   Authored-By: 360org <support@360.org.vn>"

   git push github main
   ```
6. **Lặp lại Gate 4, Gate 5 và Gate 6**:
   - Tạo tag mới ➔ Tạo release mới ➔ Chạy lại watch loop.
   - **VÒNG LẶP TIẾP TỤC CHO ĐẾN KHI KẾT QUẢ CUỐI CÙNG LÀ `success` THÌ MỚI ĐƯỢC PHÉP DỪNG!**

---

### 🏁 GATE 8: TIÊU CHÍ HOÀN THÀNH (DEFINITION OF DONE) & NGHIỆM THU
Nhiệm vụ chỉ được coi là HOÀN THÀNH khi thỏa mãn đồng thời 3 điều kiện:
1. **GitHub Actions**: Cả 2 job `build-android-release` và `build-ios-testflight` đều báo **SUCCESS** (dấu tích xanh `✓`).
2. **Apple App Store (iOS)**:
   - Bản IPA đã nạp lên TestFlight.
   - Script `appstore_distribute_and_submit.py` đã tự động tạo/cập nhật phiên bản trên App Store Connect, gán build vào tab Distribution và gửi duyệt thành công.
   - Trạng thái phiên bản trên App Store Connect là: **`🟡 Waiting for Review`** (hoặc `In Review`).
3. **Google Play Console (Android)**:
   - Bản AAB đã nạp thành công vào track `production` qua Fastlane supply.
   - Trạng thái bản phát hành trên Google Play Console là: **`Chờ duyệt`** (Under Review / Completed).

Chỉ cần hai bên Store đều ở trạng thái chờ duyệt là ĐÃ HOÀN THÀNH XUẤT SẮC!
Agent xuất Báo cáo Nghiệm thu Deployment Ready (< 1.200 ký tự) bàn giao cho Sếp Tân.

================================================================================
🏛️ [TRỤ CỘT 4: ⚙️ OUTPUT FORMAT (< 1.200 KÝ TỰ DẠNG BẢNG)]
🚨 TẤT CẢ CÁC Ô TRẠNG THÁI BAN ĐẦU BẮT BUỘC ĐỂ `⬜ PENDING`. CẤM ĐIỀN SẴN PASS!

Báo cáo nghiệm thu Release gửi Sếp Tân bắt buộc theo mẫu:

| Mục tiêu Deploy Store | Phiên bản / Định danh | Nguồn Kiểm tra / Run ID | Trạng thái Thực tế |
|---|---|---|:---:|
| **Pre-Flight Error Audit** | 10 tiêu chí từ `error_mobile.md` | Đối soát code & Fastfile | ⬜ PENDING |
| **Dart Analyze & Tests** | 0 errors, 336+ tests pass | `flutter analyze` & `flutter test` | ⬜ PENDING |
| **Git Push & Tag** | `vX.Y.Z+<BUILD>` | `git ls-remote --tags github` | ⬜ PENDING |
| **GitHub Release** | `Release vX.Y.Z+<BUILD>` | `gh release view` | ⬜ PENDING |
| **GitHub Actions Run** | Workflow `deploy.yml` | Run ID: `<ID>` (`gh run view`) | ⬜ PENDING |
| **Apple App Store Connect** | Trạng thái `Waiting for Review` | App ID: `1365622472` (API verify) | ⬜ PENDING |
| **Google Play Console** | Trạng thái `Chờ duyệt` (Production) | Track `production` (Fastlane verify) | ⬜ PENDING |
| **Sổ cái error_mobile.md** | Cập nhật lỗi mới (nếu có) | File diff `error_mobile.md` | ⬜ PENDING |

================================================================================
🥊 [ANTI-SYCOPHANCY & CALIBRATED CONFIDENCE PROTOCOL]
1. **CLAIM ≠ FACT**: "Đã release thành công" chỉ được chấp nhận khi `gh run view` báo `conclusion: success` và cả 2 Store xác nhận trạng thái chờ duyệt.
2. **Thang đo L0-L5**: Cấm nhảy cấp. Chỉ báo `L4 VERIFIED` khi Runner đã upload thành công artifact lên Store và xác nhận `Waiting for Review`.
3. **Cấm số ảo**: Không dùng từ ngữ "hoàn hảo", "100%". Báo cáo trung thực thời gian chạy của từng job.
