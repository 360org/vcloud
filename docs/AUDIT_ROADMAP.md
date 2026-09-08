# AUDIT_ROADMAP.md - VCloud Flutter Engineering Standard

## 0. Release rule
- [ ] Luôn giữ bản mới nhất trên `main`; không nhập patch/backup cũ nếu làm rollback code đã chạy ổn.
- [ ] Trước khi merge/push: `git fetch --all --prune`, kiểm tra GitLab/GitHub không lệch ngoài ý muốn.
- [ ] Mọi thay đổi phải có diff nhỏ nhất có thể; không refactor lan rộng khi chỉ cần fix một lỗi.
- [ ] Nếu chỉ là docs/config drift, sửa đúng dòng drift; không đổi behavior runtime.

## 1. Architecture boundary
- [ ] Presentation không gọi backend trực tiếp: không `OdooApiClient`, không `http`, không session/token trong widget mới.
- [ ] Presentation chỉ gọi controller/action/provider thuộc `application` hoặc repository action đã expose rõ.
- [ ] Backend/API nằm trong `features/<feature>/data/*_repository.dart` hoặc `lib/core/api/*` khi là hạ tầng chung.
- [ ] Shared widgets không biết backend; nếu cần ảnh/tệp authenticated, truyền URL/header/bytes từ layer cao hơn.
- [ ] Model parsing chịu được Odoo JSON `false`, `null`, số dạng string, thiếu field và field legacy.
- [ ] Không thêm interface/factory nếu chỉ có một implementation.

## 2. State management & lifecycle
- [ ] Riverpod provider phải có ownership rõ: `data` fetch, `application` orchestration, `presentation` render.
- [ ] `AutoDispose` cho state theo màn hình; `keepAlive` chỉ dùng cho cache/session thật sự cần giữ.
- [ ] `Timer`, `StreamSubscription`, `AnimationController`, `TextEditingController`, `ScrollController`, `FocusNode` phải dispose/cancel.
- [ ] Sau mọi `await` trong `State`/widget callback có dùng `context` hoặc `setState`: kiểm tra `mounted`/`context.mounted`.
- [ ] Không dùng bang operator (`!`) ở dữ liệu từ API/user/session nếu chưa guard rõ.
- [ ] Single-flight cho thao tác dễ spam: login, push register, refresh channel, upload/send.

## 3. Performance/loading gate
- [ ] Không cấp phát `DateFormat`, `RegExp`, formatter, parser nặng trong `build()` hoặc list item hot path.
- [ ] `Image.network` kích thước cố định phải có `cacheWidth/cacheHeight` theo DPR; không áp dụng cho full-screen viewer.
- [ ] Không sync disk I/O trên UI path: tránh `readAsBytesSync`, `writeAsBytesSync`, `listSync`, `deleteSync` trong render/tap nóng.
- [ ] Cache sync chỉ đọc RAM/web storage nhẹ; disk/mobile phải có async path và không fire-and-forget plugin init từ hàm sync.
- [ ] List chat/ticket/timesheet lớn dùng pagination/cursor/limit; không tải toàn bộ khi API hỗ trợ phân trang.
- [ ] Item list nặng có `RepaintBoundary` ở biên item, không bọc quá sâu gây tăng layer vô ích.
- [ ] Log debug trong loop/polling phải gọn; không in stack trace cho lỗi expected trong test hoặc retry flow.

## 4. Network, auth & security
- [ ] Secrets, private key, certificate, webhook, JWT/password không hard-code; dùng CI secret hoặc `--dart-define`.
- [ ] Firebase API key/public config được phép commit khi cần build native, nhưng bundle/package phải khớp app thật.
- [ ] Không log raw token: FCM token, JWT, password, session cookie, access token.
- [ ] URL attachment/download phải sanitize; không render token query ra UI nếu không cần.
- [ ] Auth fallback phải fail closed: sai mật khẩu không fallback thành session khác; multi-tenant phải có user choice rõ.
- [ ] Logout phải unregister/clear local session/cache/listener liên quan.

## 5. Flutter UI/UX quality
- [ ] UI tiếng Việt nhất quán, lỗi thân thiện, không lộ exception thô cho user production.
- [ ] Mọi nút/icon quan trọng có hit target đủ lớn, text không overflow ở mobile nhỏ.
- [ ] Loading/empty/error state đầy đủ cho list/API async.
- [ ] Form có validation tại trust boundary; không chỉ dựa backend.
- [ ] Accessibility cơ bản: semantic label cho action không có text, contrast đủ, tap target >= 44px khi khả thi.
- [ ] Dark/light theme không hard-code màu gây mất tương phản.

## 6. Testing gate
- [ ] Chạy `flutter analyze` và giữ 0 errors / 0 warnings trước khi xác nhận.
- [ ] Chạy `flutter test --exclude-tags=live-server` trước release/merge lớn.
- [ ] Với fix nhỏ, chạy targeted test liên quan và nêu rõ phạm vi.
- [ ] Test mới chỉ thêm khi logic mới không tầm thường; không tạo framework/scaffold dư.
- [ ] Live-server/integration test phải gắn tag rõ để CI thường không phụ thuộc server thật.
- [ ] Test log không nên có warning nhiễu kéo dài; mock plugin/binding khi cần.

## 7. Release hygiene
- [ ] `pubspec.yaml` version khớp tag/release `vX.Y.Z+BUILD`.
- [ ] GitHub Actions release phải chạy `flutter analyze` và `flutter test --exclude-tags=live-server` trước Fastlane.
- [ ] App Store/TestFlight/Google Play signing chỉ qua secrets; không commit `.p8`, `.p12`, provisioning profile thật.
- [ ] GitHub là mirror/build public sạch; GitLab được giữ đầy đủ asset theo yêu cầu dự án.
- [ ] Release note dùng kết quả verify hiện tại, không dùng lại số liệu audit cũ làm bằng chứng mới.

## 8. Odoo/backend boundary
- [ ] Odoo schema/server/module thay đổi nằm ở repo Odoo module, không sửa trong Flutter client.
- [ ] Flutter không SSH/deploy Kubernetes/Odoo production trừ khi Sếp yêu cầu rõ và dùng skill/quy trình backup.
- [ ] Nếu API thiếu limit/search cần ghi rõ yêu cầu cho `v_mobile`; không tự đổi contract trong mobile repo.
- [ ] Contract JSON thay đổi phải cập nhật repository parser + tests mapping.

## 9. Current known debt
- [ ] Refactor dần các presentation widget còn dùng `odooApiClient` trực tiếp sang repository/helper/action.
- [ ] Chuẩn hóa Firebase config generation để giảm lệch giữa `Env`, `firebase_push_options.dart`, native service files.
- [ ] Audit dependency upgrade riêng: `golden_toolkit` discontinued, `record_linux` override, major packages outdated.
