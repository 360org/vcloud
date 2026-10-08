# Báo Cáo Phân Tích Nguyên Nhân Gốc Rễ: Lệch Hình Ảnh Khi Xem Ảnh Trong Chat V2 (Root Cause Analysis)

> **Mã lỗi**: `BUG-CHATV2-IMG-MISMATCH`  
> **Thời gian điều tra**: 2026-10-08  
> **Phạm vi**: Chat V2 Module (`chat_v2_detail_screen.dart`, `chat_v2_message_item.dart`, `chat_v2_image_viewer_screen.dart`, `chat_bubbles.dart`)  
> **Chế độ**: `STRICT READ-ONLY INVESTIGATION`  
> **Trạng thái**: Đã xác minh Root Cause ➔ Sẵn sàng cho Pha 2 (Fix Code)

---

## 1. Mô tả Hiện Tượng (Bug Symptom)
Khi người dùng đang ở trong màn hình trò chuyện (Chat V2):
- Nhấn vào một hình ảnh cụ thể trên bong bóng tin nhắn (hoặc gallery ảnh).
- Màn hình phóng to/trình xem ảnh (`ChatV2ImageViewerScreen`) lại mở ra một hình ảnh khác (thường là ảnh cũ hơn trong lịch sử, hoặc ảnh đầu tiên trong mẻ gửi).
- Hiệu ứng Hero Animation bị giật hoặc bay lệch từ ảnh này sang ảnh khác.

---

## 2. Phân Tích Nguyên Nhân Gốc Rễ (Root Cause Analysis)

### 🔴 Nguyên nhân 1: Logic `indexWhere` So Khớp Lỏng Lẻo Trong `_handleChannelImageTap`
* **Vị trí**: `lib/features/chat_v2/presentation/screens/chat_v2_detail_screen.dart:765-769`
* **Code thực tế**:
  ```dart
  var initialIndex = channelImages.indexWhere((x) =>
      (x.id.isNotEmpty && targetAtt.id.isNotEmpty && x.id == targetAtt.id) ||
      (x.name.isNotEmpty && x.name == targetAtt.name) ||
      (x.url != null && targetAtt.url != null && x.url == targetAtt.url));
  ```
* **Cơ chế gây lỗi**:
  - Dùng toán tử `||` (OR) với fallback so sánh tên file: `(x.name.isNotEmpty && x.name == targetAtt.name)`.
  - Trên điện thoại di động, ảnh chụp từ camera hoặc ảnh chụp màn hình thường có tên mặc định trùng nhau như `image.png`, `image.jpg`, `photo.jpg`, `Screenshot.png`, `image_picker_...`.
  - Khi người dùng gửi ảnh mới có cùng tên `image.png` (dù ID là `105` khác với ID `80` của ảnh cũ), điều kiện `x.name == targetAtt.name` vẫn trả về `true` ngay tại ảnh cũ (ID `80`).
  - `indexWhere` lập tức trả về chỉ mục của ảnh cũ trong `channelImages` thay vì ảnh người dùng vừa nhấn.

---

### 🔴 Nguyên nhân 2: Bỏ Rơi `initialIndex` Của Tin Nhắn Khi Có `onImageTap` Callback
* **Vị trí**: `lib/features/chat_v2/presentation/widgets/chat_v2_message_item.dart:1044-1048`
* **Code thực tế**:
  ```dart
  onTap: () {
    if (onImageTap != null) {
      onImageTap!(att, heroTag);
      return;
    }
    Navigator.of(context).push(
      ChatV2ImageViewerScreen.route(
        images: allImages,
        initialIndex: initialIndex,
        ...
      ),
    );
  },
  ```
* **Cơ chế gây lỗi**:
  - Trong `ChatV2MessageItem`, Grid/Wrap đã tính toán chính xác `initialIndex` và danh sách ảnh lọc `allImages: imageAttachments`.
  - Tuy nhiên, khi `chat_v2_detail_screen.dart` truyền callback `onImageTap: (att, heroTag) => _handleChannelImageTap(att, heroTag, messages)` (dòng 1387), nhánh `onImageTap` được kích hoạt và **vứt bỏ hoàn toàn `initialIndex` và `allImages`** của tin nhắn đó.
  - Hàm `_handleChannelImageTap` phải tự quét ngược lại toàn bộ tin nhắn để đoán lại index bằng tên file, dẫn tới sai lệch.

---

### 🔴 Nguyên nhân 3: Xung Đột Hero Tag Giữa Bubble Chat và PageController
* **Vị trí**:
  - Khởi tạo Tag tại Bubble: `chat_v2_message_item.dart:1033`
    ```dart
    final heroTag = 'chat_v2_img_${att.id.isNotEmpty ? att.id : (att.url ?? att.name)}_${att.hashCode}';
    ```
  - Nhận Tag tại ImageViewer: `chat_v2_image_viewer_screen.dart:138-142`
    ```dart
    final tag = (i == widget.initialIndex && widget.heroTag != null)
        ? widget.heroTag
        : 'chat_v2_gallery_${att.id.isNotEmpty ? att.id : i}_$i';
    ```
* **Cơ chế gây lỗi**:
  - Do `initialIndex` bị tính sai, `widget.heroTag` (vốn gắn với ảnh A vừa click trên Bubble) lại được gán cho ảnh B ở vị trí `widget.initialIndex` trong ImageViewer.
  - Hero Animation của Flutter sẽ nối ảnh A trên chat với ảnh B trong viewer, gây hiện tượng bay nhầm ảnh hoặc giật hình.
  - Ngoài ra, `att.hashCode` thay đổi khi tin nhắn rebuild, làm mất liên kết Hero Tag.

---

### 🔴 Nguyên nhân 4: Ô Nhiễm Cache RAM Theo Tên File Chung (`imageCache[a.name]`)
* **Vị trí**:
  - `chat_v2_message_item.dart:2157-2164`
  - `chat_v2_detail_screen.dart:733`
* **Code thực tế**:
  ```dart
  final existingBytes = a.bytes ??
      ChatV2AttachmentImage.imageCache[a.id] ??
      ChatV2AttachmentImage.imageCache[a.name] ??
      ...
  ```
* **Cơ chế gây lỗi**:
  - Khi lưu cache ảnh, nếu fallback lưu/tra cứu theo `a.name` (ví dụ `image.png`), thì ảnh thứ 2 có cùng tên `image.png` sẽ đọc nhầm dữ liệu byte trong RAM của ảnh thứ 1.
  - Dẫn đến việc mở ảnh mới nhưng nội dung hiển thị lại là ảnh cũ đã nạp trước đó.

---

## 3. Bảng Đối Soát Vị Trí Lỗi

| STT | Điểm Nghẽn / Lỗi Code | Vị Trí File & Dòng Code | Cơ Chế Gây Lệch Ảnh | Mức Độ |
| :---: | :--- | :--- | :--- | :---: |
| 1 | Lệch Index do `indexWhere` dùng OR lỏng lẻo | `chat_v2_detail_screen.dart:765-769` | `x.name == targetAtt.name` bắt nhầm ảnh cũ có cùng tên trong lịch sử chat | **CRITICAL** |
| 2 | Vứt bỏ `initialIndex` & `allImages` của tin nhắn | `chat_v2_message_item.dart:1044-1048` | `onImageTap` chỉ truyền `(att, heroTag)`, bỏ qua index gốc của mẻ ảnh | **HIGH** |
| 3 | Hero Tag bay nhầm sang ảnh khác | `chat_v2_image_viewer_screen.dart:138-142` | Hero Tag của ảnh được tap bị gán cho ảnh ở index lệch | **HIGH** |
| 4 | Trùng lặp cache RAM theo tên file | `chat_v2_message_item.dart:2157-2164` | `imageCache[a.name]` trả về byte của ảnh trước đó có cùng tên | **MEDIUM** |
| 5 | Gắn cứng `first` attachment trong Chat V1 | `chat_bubbles.dart:142-144` | Luôn lấy attachment đầu tiên của message | **LOW** |

---

## 4. Phương Án Phẫu Thuật Đề Xuất Cho Pha 2 (Fix Implementation Plan)

1. **Chuẩn hóa nhận diện duy nhất (Strict Identity Matching) trong `_handleChannelImageTap`**:
   - Ưu tiên 1: Nếu `targetAtt.id` hợp lệ và khác `'0'` ➔ CHỈ so khớp `x.id == targetAtt.id`, tuyệt đối không dùng `|| name`.
   - Ưu tiên 2: Nếu không có ID nhưng có `url` ➔ So khớp `x.url == targetAtt.url`.
   - Ưu tiên 3: Nếu không có cả ID và URL (ảnh pending) ➔ So khớp kết hợp `(x.name == targetAtt.name && x.bytes == targetAtt.bytes)`.
2. **Bổ sung `messageId` và `attachmentIndex` vào định danh**:
   - Gắn `messageId` vào `heroTag` và `ChatV2Attachment` để phân biệt ảnh giữa các tin nhắn khác nhau:
     `heroTag = 'chat_v2_${message.id}_${att.id}_$index'`.
3. **Loại bỏ cache fallback theo tên file chung**:
   - Tuyệt đối không tra cứu `imageCache[a.name]` khi `a.name` là tên file generic (`image.png`, `photo.jpg`...).
4. **Đồng bộ callback `onImageTap`**:
   - Truyền kèm `messageAttachments` và `initialIndex` trong callback để viewer có thể fallback chuẩn xác vào mẻ ảnh của chính tin nhắn đó khi cần.
