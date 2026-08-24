# AUDIT_ROADMAP.md - VCloud Audit Roadmap

## 1. Kiến trúc source
- [ ] Root chỉ giữ `README.md`, `AGENTS.md`, `CLAUDE.md`, `.claude/`, cấu hình build và mã nguồn.
- [ ] Tài liệu chi tiết nằm trong `docs/*`: `IDEA`, `REQUIREMENTS`, `SPEC`, `ARCH`, `PLAN`, `DEPLOY_GUIDE`, `CHANGELOGS`, `AUDIT_REPORT`.
- [ ] Không còn tài liệu public gọi VCloud là tên repo cũ; chỉ nhắc tên cũ khi mô tả alias/path lịch sử.

## 2. Flutter quality gate
- [ ] Chạy `flutter pub get`.
- [ ] Chạy `flutter analyze` và giữ 0 errors / 0 warnings.
- [ ] Chạy `flutter test` hoặc ghi rõ blocker môi trường.
- [ ] Kiểm tra bang operator mới, `context.mounted` sau `await`, dispose controller/timer.

## 3. Performance/loading gate
- [ ] Chat list/detail không cấp phát formatter/regex trong hot path.
- [ ] Avatar/network image có decode size phù hợp DPR khi hiển thị kích thước cố định.
- [ ] List item nặng có `RepaintBoundary` khi cần cô lập repaint.
- [ ] Lookup project/task/tag có limit/search phía backend khi liên quan `v_mobile`.

## 4. Release hygiene gate
- [ ] Secret scan trước commit/push: token, password, private key, certificate, local path.
- [ ] `pubspec.yaml` version khớp tag `vX.Y.Z+BUILD`.
- [ ] GitHub chỉ còn branch `main`; release build chạy từ tag `v*`.
- [ ] Release body dùng nội dung audit hiện tại, không dùng kết quả test cũ làm bằng chứng mới.

## 5. Boundary gate
- [ ] VCloud task chỉ build/release mobile app.
- [ ] Không SSH/deploy Kubernetes/Odoo production khi yêu cầu là release/build mobile.
- [ ] `v_mobile` chỉ deploy local/production khi Sếp yêu cầu rõ và theo quy trình backup/test/verify.
