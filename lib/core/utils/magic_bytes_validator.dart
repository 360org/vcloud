import 'dart:typed_data';

/// Magic Bytes Validator to detect payload headers, error JSON/HTML strings,
/// and valid ZIP / PDF binary signatures.
class MagicBytesValidator {
  /// Returns true if bytes start with JSON '{' (0x7B) or HTML '<' (0x3C) error payload.
  static bool isErrorPayload(Uint8List bytes) {
    if (bytes.isEmpty) return true;
    final firstByte = bytes[0];
    return firstByte == 0x7B || firstByte == 0x3C; // '{' or '<'
  }

  /// Returns true if bytes match valid ZIP signature `[0x50, 0x4B]` ("PK").
  static bool isValidZipBytes(Uint8List bytes) {
    if (bytes.length < 2) return false;
    return bytes[0] == 0x50 && bytes[1] == 0x4B; // "PK"
  }

  /// Returns true if bytes match valid PDF signature `%PDF` (`[0x25, 0x50, 0x44, 0x46]`).
  static bool isValidPdfBytes(Uint8List bytes) {
    if (bytes.length < 4) return false;
    return bytes[0] == 0x25 && bytes[1] == 0x50 && bytes[2] == 0x44 && bytes[3] == 0x46; // %PDF
  }

  /// Returns true if bytes match PNG signature `[0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]`.
  static bool isPngBytes(Uint8List bytes) {
    if (bytes.length < 8) return false;
    return bytes[0] == 0x89 &&
        bytes[1] == 0x50 &&
        bytes[2] == 0x4E &&
        bytes[3] == 0x47 &&
        bytes[4] == 0x0D &&
        bytes[5] == 0x0A &&
        bytes[6] == 0x1A &&
        bytes[7] == 0x0A;
  }

  /// Returns true if bytes match Odoo default placeholder.png (6078 bytes, PNG 256x256).
  /// Odoo returns this image fallback when an attachment is missing or lacks read permissions.
  static bool isOdooPlaceholder(Uint8List bytes) {
    return bytes.length == 6078 && isPngBytes(bytes);
  }

  /// Returns true if non-image document bytes (DOCX, XLSX, PDF, ZIP, TXT, etc.)
  /// were mistakenly replaced by an image payload (such as Odoo's placeholder.png).
  static bool isMistakenImagePayloadForDocument(String filename, Uint8List bytes) {
    if (bytes.isEmpty) return false;
    final lower = filename.trim().toLowerCase();
    final isOfficeOrDoc = lower.endsWith('.docx') ||
        lower.endsWith('.doc') ||
        lower.endsWith('.xlsx') ||
        lower.endsWith('.xls') ||
        lower.endsWith('.pdf') ||
        lower.endsWith('.pptx') ||
        lower.endsWith('.ppt') ||
        lower.endsWith('.zip') ||
        lower.endsWith('.rar') ||
        lower.endsWith('.7z') ||
        lower.endsWith('.txt');

    if (!isOfficeOrDoc) return false;

    // Document expected, but got Odoo placeholder or unexpected PNG signature
    return isOdooPlaceholder(bytes) || isPngBytes(bytes);
  }
}
