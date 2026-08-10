String cleanHtmlText(Object? value) {
  if (value == null || value == false) return '';

  final text = value.toString().trim();
  if (text.isEmpty || text == 'False' || text == 'false') return '';

  // Decode html entities first so &lt;br&gt; becomes <br> before stripping/replacing
  final decodedFirst = _decodeHtmlEntities(text);

  final withoutHiddenBlocks = decodedFirst
      .replaceAll(
        RegExp(
          r'<\s*(script|style)[^>]*>.*?<\s*/\s*\1\s*>',
          caseSensitive: false,
          dotAll: true,
        ),
        '',
      )
      .replaceAll(RegExp(r'<!--.*?-->', dotAll: true), '');

  final withBreaks = withoutHiddenBlocks
      .replaceAll(RegExp(r'<\s*br\s*/?\s*>', caseSensitive: false), '\n')
      .replaceAll(RegExp(r'</\s*p\s*>', caseSensitive: false), '\n')
      .replaceAll(RegExp(r'</\s*div\s*>', caseSensitive: false), '\n')
      .replaceAll(RegExp(r'</\s*li\s*>', caseSensitive: false), '\n');
  final withoutTags = withBreaks.replaceAll(RegExp(r'<[^>]*>'), '');

  return withoutTags
      .split('\n')
      .map((line) => line.replaceAll(RegExp(r'[ \t]+'), ' ').trim())
      .where((line) => line.isNotEmpty)
      .join('\n')
      .trim();
}

String _decodeHtmlEntities(String text) {
  const entities = <String, String>{
    '&amp;': '&',
    '&lt;': '<',
    '&gt;': '>',
    '&quot;': '"',
    '&#39;': "'",
    '&apos;': "'",
    '&nbsp;': ' ',
  };

  var decoded = text;
  for (final entry in entities.entries) {
    decoded = decoded.replaceAll(entry.key, entry.value);
  }

  return decoded
      .replaceAllMapped(RegExp(r'&#(\d+);'), (match) {
        final codePoint = int.tryParse(match.group(1) ?? '');
        return codePoint == null
            ? match.group(0)!
            : String.fromCharCode(codePoint);
      })
      .replaceAllMapped(RegExp(r'&#x([0-9a-fA-F]+);'), (match) {
        final codePoint = int.tryParse(match.group(1) ?? '', radix: 16);
        return codePoint == null
            ? match.group(0)!
            : String.fromCharCode(codePoint);
      });
}
