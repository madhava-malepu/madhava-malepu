/// Input sanitization utility for Surpl.
/// Use this before writing ANY user-entered text to Firestore.
/// Strips HTML, script tags, and dangerous characters.
/// All form submissions should run through these methods.

class InputSanitizer {
  // Strip HTML tags, script tags, and dangerous characters
  static String sanitize(String input) {
    if (input.isEmpty) return input;

    String result = input.trim();

    // Remove script tags and content between them
    result = result.replaceAll(
        RegExp(r'<script[^>]*>.*?</script>', caseSensitive: false, dotAll: true), '');

    // Remove all HTML/XML tags
    result = result.replaceAll(RegExp(r'<[^>]+>'), '');

    // Remove javascript: protocol
    result = result.replaceAll(
        RegExp(r'javascript\s*:', caseSensitive: false), '');

    // Remove null bytes
    result = result.replaceAll('\x00', '');

    // Normalize whitespace
    result = result.replaceAll(RegExp(r'\s+'), ' ').trim();

    return result;
  }

  // Sanitize and enforce max length
  static String sanitizeText(String input, {int maxLength = 200}) {
    final cleaned = sanitize(input);
    return cleaned.length > maxLength
        ? cleaned.substring(0, maxLength)
        : cleaned;
  }

  // For names — allow letters, spaces, dots, hyphens only
  static String sanitizeName(String input, {int maxLength = 100}) {
    final cleaned = sanitize(input);
    // Remove anything that's not a letter, space, hyphen, dot, or apostrophe
    final nameOnly = cleaned.replaceAll(
        RegExp(r"[^a-zA-Z\u0900-\u097F\s\-\.'']"), '');
    return nameOnly.length > maxLength
        ? nameOnly.substring(0, maxLength)
        : nameOnly.trim();
  }

  // For phone numbers — digits and + only
  static String sanitizePhone(String input) {
    return input.replaceAll(RegExp(r'[^\d+]'), '').trim();
  }

  // For FSSAI numbers — digits only, exactly 14 chars
  static String sanitizeFssai(String input) {
    final digits = input.replaceAll(RegExp(r'[^\d]'), '');
    return digits.length > 14 ? digits.substring(0, 14) : digits;
  }

  // For address — allow alphanumeric, spaces, commas, hyphens, dots
  static String sanitizeAddress(String input, {int maxLength = 300}) {
    final cleaned = sanitize(input);
    final addrOnly = cleaned.replaceAll(
        RegExp(r'[^a-zA-Z0-9\u0900-\u097F\s,\-\./#]'), '');
    return addrOnly.length > maxLength
        ? addrOnly.substring(0, maxLength)
        : addrOnly.trim();
  }

  // For prices — ensure it's a valid positive number >= 29
  static double? sanitizePrice(String input) {
    final trimmed = input.trim();
    final value = double.tryParse(trimmed);
    if (value == null || value < 29) return null;
    return value;
  }

  // For bag titles — alphanumeric, spaces, common punctuation
  static String sanitizeTitle(String input, {int maxLength = 100}) {
    final cleaned = sanitize(input);
    return cleaned.length > maxLength
        ? cleaned.substring(0, maxLength)
        : cleaned.trim();
  }

  // Validate phone — must be 10 digits (Indian) or start with + and be 10-15 digits
  static bool isValidIndianPhone(String phone) {
    final cleaned = sanitizePhone(phone);
    if (cleaned.startsWith('+')) {
      return RegExp(r'^\+\d{10,15}$').hasMatch(cleaned);
    }
    return RegExp(r'^\d{10}$').hasMatch(cleaned);
  }

  // Validate FSSAI — must be exactly 14 digits
  static bool isValidFssai(String fssai) {
    final cleaned = sanitizeFssai(fssai);
    return cleaned.length == 14 && RegExp(r'^\d{14}$').hasMatch(cleaned);
  }

  // Validate referral code — 8 uppercase alphanumeric chars
  static bool isValidReferralCode(String code) {
    return RegExp(r'^[A-Z0-9]{8}$').hasMatch(code.trim().toUpperCase());
  }

  // For GSTIN — uppercase alphanumeric only, exactly 15 chars
  static String sanitizeGstin(String input) {
    final cleaned = input.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
    return cleaned.length > 15 ? cleaned.substring(0, 15) : cleaned;
  }

  // Validate GSTIN — standard 15-character format: 2-digit state code,
  // 10-char PAN, 1-digit entity number, 'Z' by default, 1 checksum char.
  // Same pattern already confirmed correct against a real GSTIN in the
  // admin panel's vendor approval flow — kept identical so both sides
  // agree on what counts as valid.
  static bool isValidGstin(String gstin) {
    final cleaned = sanitizeGstin(gstin);
    return RegExp(r'^[0-9]{2}[A-Z]{5}[0-9]{4}[A-Z]{1}[1-9A-Z]{1}Z[0-9A-Z]{1}$')
        .hasMatch(cleaned);
  }
}