class PhoneUtils {
  static String? normalize(String input) {
    final digits = input.replaceAll(RegExp(r'\D'), '');
    if (digits.length < 10) return null;
    if (digits.length == 10) return '+91$digits';
    if (digits.length == 11 && digits.startsWith('0')) {
      return '+91${digits.substring(1)}';
    }
    if (digits.length == 12 && digits.startsWith('91')) return '+$digits';
    if (digits.length > 12) return '+91${digits.substring(digits.length - 10)}';
    return null;
  }
}
