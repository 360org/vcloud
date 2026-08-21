# 🔄 HƯỚNG DẪN AI AGENT (ANTIGRAVITY) KHÔI PHỤC DỰ ÁN (ROLLBACK CHECKPOINT PLAYBOOK)

> **Dành riêng cho Agent Antigravity / AI Assistant**  
> Khi Sếp Châu yêu cầu: **"rollback"**, **"quay lại"**, **"khôi phục"**, **"rollback lại"**, hoặc đính kèm/thả file `.md` này vào khung chat, AI Agent BẮT BUỘC phải thực thi quy trình khôi phục tự động bên dưới để đưa toàn bộ dự án về điểm mốc an toàn PASSED 100%.

---

## 📌 1. THÔNG TIN ĐIỂM MỐC AN TOÀN (SAFE CHECKPOINT METADATA)

* **Dự án:** VCloud Mobile App (`vclients`)
* **Mã doanh nghiệp:** W360S JOINT STOCK COMPANY (`ZC3H8887XS`)
* **Bundle ID:** `com.w360s.wcloudapp`
* **Nguồn điểm mốc ổn định:** cấu hình release mobile hiện hành
* **Commit Checkpoint PASSED chuẩn:** lưu trong lịch sử Git nội bộ
* **Mật khẩu Apple App-Specific Password:** lưu trong CI Secrets, không ghi vào repo
* **Trạng thái Build:** ✅ PASSED 100% trên TestFlight iOS & Android (APK + AAB).

---

## ⚡ 2. HƯỚNG DẪN THỰC THI TỰ ĐỘNG CHO AI AGENT (AGENT AUTOMATED STEPS)

Khi nhận được lệnh Rollback từ Sếp Châu, Agent thực hiện chính xác 5 bước theo thứ tự sau (không cần hỏi thêm):

### 🔹 BƯỚC 1: Kiểm tra working tree & dọn dẹp biến rác
```bash
git status --short
```
* Nếu có code dở dang chưa lưu mà Sếp yêu cầu đập đi: Tự động xóa rác hoặc checkout sạch sẽ.

### 🔹 BƯỚC 2: Đồng bộ mã nguồn mới nhất từ Remote điểm mốc
```bash
git fetch --all
git checkout <release-source>
git reset --hard origin/<release-source>
```

### 🔹 BƯỚC 3: Dọn dẹp triệt để rác build local (Untracked files & cache)
```bash
git clean -fd
```

### 🔹 BƯỚC 4: Phục hồi và kiểm tra gói Flutter Dependencies
```bash
flutter pub get
```

### 🔹 BƯỚC 5: Kiểm tra xác minh Ancestry và báo cáo Sếp
```bash
git merge-base --is-ancestor HEAD origin/<release-source>
```

---

## 📋 3. MẪU BÁO CÁO PHẢN HỒI SẾP SAU KHI ROLLBACK THÀNH CÔNG

Sau khi hoàn thành 5 bước trên, Agent lập tức phản hồi Sếp theo cấu trúc:

```text
✅ ĐÃ ROLLBACK DỰ ÁN VỀ ĐIỂM MỐC AN TOÀN THÀNH CÔNG!

• Nguồn hiện tại: release mobile
• Commit Checkpoint: PASSED TestFlight 100%
• Trạng thái Codebase: Sạch sẽ, không còn lỗi, sẵn sàng phát triển tiếp.
• Dependencies: Đã nạp lại flutter pub get thành công.
```
