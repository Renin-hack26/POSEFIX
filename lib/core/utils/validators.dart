/// Form validators for auth + profile forms (PLANNING.md §5.1, §10 P-11..P-16).
///
/// Messages are user-facing final copy — keep them stable.
abstract final class Validators {
  static final RegExp _email =
      RegExp(r"^[A-Za-z0-9._%+\-]+@[A-Za-z0-9.\-]+\.[A-Za-z]{2,}$");

  static String? required(String? value, {String field = 'This field'}) {
    if (value == null || value.trim().isEmpty) return '$field is required.';
    return null;
  }

  static String? name(String? value, {String field = 'Name'}) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return '$field is required.';
    if (v.length < 2) return '$field must be at least 2 characters.';
    if (v.length > 50) return '$field must be 50 characters or fewer.';
    if (!RegExp(r"^[A-Za-zÀ-ɏ' -]+$").hasMatch(v)) {
      return '$field may only contain letters.';
    }
    return null;
  }

  static String? email(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return 'Email address is required.';
    if (!_email.hasMatch(v)) return 'Enter a valid email address.';
    return null;
  }

  /// ≥ 8 chars, at least one letter and one digit (PLANNING P-14).
  static String? password(String? value) {
    final v = value ?? '';
    if (v.isEmpty) return 'Password is required.';
    if (v.length < 8) return 'Use at least 8 characters.';
    if (!v.contains(RegExp(r'[A-Za-z]')) || !v.contains(RegExp(r'[0-9]'))) {
      return 'Include at least one letter and one number.';
    }
    return null;
  }

  static String? confirmPassword(String? value, String original) {
    if (value == null || value.isEmpty) return 'Please confirm your password.';
    if (value != original) return 'Passwords do not match.';
    return null;
  }

  /// Date of birth: required, not in the future, age ≥ 13 (P-12).
  static String? dateOfBirth(DateTime? value, {DateTime? now}) {
    if (value == null) return 'Date of birth is required.';
    final ref = now ?? DateTime.now();
    if (value.isAfter(ref)) return 'Date of birth cannot be in the future.';
    final age = ref.year -
        value.year -
        ((ref.month < value.month ||
                (ref.month == value.month && ref.day < value.day))
            ? 1
            : 0);
    if (age < 13) return 'You must be at least 13 years old.';
    if (age > 120) return 'Enter a valid date of birth.';
    return null;
  }

  /// 6-digit numeric one-time code.
  static String? otpCode(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return 'Enter the 6-digit code.';
    if (!RegExp(r'^\d{6}$').hasMatch(v)) return 'The code is 6 digits.';
    return null;
  }

  /// Numeric range that may be left empty (weight/height are optional).
  static String? optionalNumber(
    String? value, {
    required double min,
    required double max,
    required String label,
  }) {
    final s = value?.trim() ?? '';
    if (s.isEmpty) return null;
    final n = double.tryParse(s.replaceAll(',', '.'));
    if (n == null) return 'Enter a valid number.';
    if (n < min || n > max) {
      return '$label must be between ${min.toStringAsFixed(0)} and ${max.toStringAsFixed(0)}.';
    }
    return null;
  }
}
