import 'dart:convert';

/// Parses model output into a JSON object, tolerating common failure modes:
/// truncated braces, trailing newlines, and stray surrounding text.
class JsonRepair {
  /// Returns a decoded Map if the [raw] string can be repaired into valid
  /// JSON, otherwise null.
  static Map<String, dynamic>? tryParse(String raw) {
    if (raw.isEmpty) return null;

    var candidates = <String>[
      raw.trim(),
    ];

    // Truncated JSON missing the closing brace.
    candidates.add('${candidates.first}${_missingBraces(candidates.first)}');

    // JSON object embedded in surrounding text: take the balanced {...} block.
    final balanced = _extractBalancedObject(raw);
    if (balanced != null) candidates.add(balanced);

    for (final c in candidates) {
      try {
        final decoded = jsonDecode(c);
        if (decoded is Map<String, dynamic>) return decoded;
      } catch (_) {
        // try next candidate
      }
    }
    return null;
  }

  static String _missingBraces(String s) {
    var opens = 0;
    for (final ch in s.split('')) {
      if (ch == '{') opens++;
      if (ch == '}') opens--;
    }
    return opens > 0 ? '}' * opens : '';
  }

  static String? _extractBalancedObject(String s) {
    final start = s.indexOf('{');
    if (start < 0) return null;
    var depth = 0;
    var inString = false;
    var escaped = false;
    for (var i = start; i < s.length; i++) {
      final ch = s[i];
      if (inString) {
        if (escaped) {
          escaped = false;
        } else if (ch == r'\') {
          escaped = true;
        } else if (ch == '"') {
          inString = false;
        }
        continue;
      }
      if (ch == '"') {
        inString = true;
      } else if (ch == '{') {
        depth++;
      } else if (ch == '}') {
        depth--;
        if (depth == 0) return s.substring(start, i + 1);
      }
    }
    return null;
  }
}
