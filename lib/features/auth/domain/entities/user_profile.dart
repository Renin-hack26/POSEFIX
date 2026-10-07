/// User domain entities — pure Dart, no framework imports (Clean Architecture).
library;

enum Gender { male, female, preferNotToSay }

extension GenderX on Gender {
  /// Storage / API value.
  String get wireName => name;

  /// Avatar selection rule (PLANNING §5.3): unspecified -> male avatar.
  bool get usesMaleAvatar => this == Gender.male || this == Gender.preferNotToSay;

  String get label => switch (this) {
        Gender.male => 'Male',
        Gender.female => 'Female',
        Gender.preferNotToSay => 'Prefer not to say',
      };
}

Gender genderFromWire(String? value) =>
    Gender.values.firstWhere((g) => g.name == value, orElse: () => Gender.preferNotToSay);

/// Signed-in FixPose user.
class UserProfile {
  const UserProfile({
    required this.uid,
    required this.firstName,
    required this.middleName,
    required this.lastName,
    required this.dateOfBirth,
    required this.gender,
    required this.email,
    this.weightKg,
    this.heightCm,
  });

  final String uid;
  final String firstName;
  final String middleName;
  final String lastName;
  final DateTime dateOfBirth;
  final Gender gender;
  final String email;
  final double? weightKg;
  final double? heightCm;

  String get fullName =>
      [firstName, middleName, lastName].where((s) => s.trim().isNotEmpty).join(' ');
}

/// Sign-up form payload (all fields validated by Validators before use).
class SignUpData {
  const SignUpData({
    required this.firstName,
    this.middleName = '',
    this.lastName = '',
    required this.dateOfBirth,
    required this.gender,
    required this.email,
    this.weightKg,
    this.heightCm,
  });

  final String firstName;
  final String middleName;
  final String lastName;
  final DateTime dateOfBirth;
  final Gender gender;
  final String email;
  final double? weightKg;
  final double? heightCm;
}
