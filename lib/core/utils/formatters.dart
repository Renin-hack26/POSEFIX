/// Display-only formatters (UI concerns, no business logic).
abstract final class Formatters {
  static const List<String> _months = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December',
  ];

  /// "14 March 2004" — date-of-birth display (sample screen 03).
  static String dateLong(DateTime d) =>
      '${d.day} ${_months[d.month - 1]} ${d.year}';

  /// "al•••@gmail.com" — keeps first 2 chars of the local part (sample 04/05).
  static String maskEmail(String email) {
    final at = email.indexOf('@');
    if (at <= 0) return email;
    final local = email.substring(0, at);
    final domain = email.substring(at);
    final keep = local.length >= 2 ? 2 : 1;
    return '${local.substring(0, keep)}•••$domain';
  }

  /// "00:42" — countdown clock for OTP resend and rest timers.
  static String clock(int totalSeconds) {
    final safe = totalSeconds < 0 ? 0 : totalSeconds;
    final m = (safe ~/ 60).toString().padLeft(2, '0');
    final s = (safe % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }
}
