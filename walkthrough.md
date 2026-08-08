# Walkthrough: Attachment Upload API Fix & Real-Time Sync

Resolved the **`HTTP 400 Bad Request`** error on `/api/v1/mobile/attachments/upload` across Odoo 17 (`v_mobile`) and Flutter Mobile (`vclients`), and verified all payload modes (JSON Base64 & Multipart) and test suites.

---

## 🛠️ 1. Changes Made

### 1. **Odoo Backend Attachment Controller (`v_mobile`)**
- **[attachments.py](file:///media/tanma/DATA/save/mobile/v_mobile/controllers/attachments.py)**:
  - Enhanced `upload(self, **kw)` to parse Base64 payload from `base64`, `datas`, and `data` keys.
  - Extracted filename from `filename`, `name`, `kw.filename`, `kw.name`, or `uploaded.filename`.
  - Allowed `res_model`/`model` and `res_id`/`id` parameter aliases.
  - Reordered validation logic so filename defaults safely without throwing premature `missing_filename` 400 errors during multipart uploads.

### 2. **Flutter Mobile Repository (`vclients`)**
- **[mobile_attachment_repository.dart](file:///media/tanma/DATA/save/mobile/vclients/lib/core/api/mobile_attachment_repository.dart)**:
  - Updated `MobileAttachmentRepository.upload()` payload to include both `base64` and `datas` fields in the JSON body payload.
  - **[chat_openapi_mapping_test.dart](file:///media/tanma/DATA/save/mobile/vclients/test/chat_openapi_mapping_test.dart)**: Added test assertions verifying both `base64` and `datas` payload fields.

---

## 🧪 2. Verification & Test Results

### 1. **Attachment Upload Endpoint Multi-Mode Integration Test**
```bash
python3 -c "
import requests, base64
...
res1 = requests.post('/api/v1/mobile/attachments/upload', json={'filename': 'doc.txt', 'datas': b64}) # 201 Created ✅
res2 = requests.post('/api/v1/mobile/attachments/upload', json={'filename': 'doc.txt', 'base64': b64}) # 201 Created ✅
res3 = requests.post('/api/v1/mobile/attachments/upload', files={'file': ('file.txt', b'content')})  # 201 Created ✅
"
```
- **Result**:
  - `JSON mode (datas key)` ➔ **`HTTP 201 Created`** (Attachment ID `1051`)
  - `JSON mode (base64 key)` ➔ **`HTTP 201 Created`** (Attachment ID `1052`)
  - `Multipart mode` ➔ **`HTTP 201 Created`** (Attachment ID `1053`)

### 2. **Flutter Static Analysis**
- **Command**: `/home/tanma/flutter/bin/flutter analyze`
- **Result**: `No issues found! (ran in 2.6s)`

### 3. **Flutter Test Suite**
- **Command**: `/home/tanma/flutter/bin/flutter test`
- **Result**: `All 63 tests passed!`

---

## 📊 3. Verification Checklist

| Check / Requirement | Status |
| :--- | :--- |
| JSON Base64 Upload (`datas` key from Flutter) | ✅ `201 CREATED` |
| JSON Base64 Upload (`base64` key standard) | ✅ `201 CREATED` |
| Multipart Form-Data Upload | ✅ `201 CREATED` |
| Flutter Version protection (`pubspec.yaml` `2.4.0+28`) | ✅ `UNCHANGED` |
| Flutter Static Analysis (`flutter analyze`) | ✅ `0 ERRORS / 0 WARNINGS` |
| Flutter Test Suite (`flutter test`) | ✅ `63/63 PASSED` |
