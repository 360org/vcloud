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
}
