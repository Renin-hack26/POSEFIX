/// P1 auth E2E — input validation contract for every auth/profile form.
/// Messages are user-facing final copy (validators.dart); these tests pin
/// them so a refactor can never silently weaken what the forms accept.
library;

import 'package:fixpose/core/utils/validators.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('required', () {
    test('blank is rejected, text passes', () {
      expect(Validators.required(null), isNotNull);
      expect(Validators.required('   '), isNotNull);
      expect(Validators.required('x'), isNull);
    });
  });

  group('email', () {
    test('accepts real addresses, rejects junk', () {
      expect(Validators.email('you@example.com'), isNull);
      expect(Validators.email('  spaced@x.io  '), isNull,
          reason: 'surrounding whitespace is trimmed');
      expect(Validators.email(''), isNotNull);
      expect(Validators.email('not-an-email'), isNotNull);
      expect(Validators.email('a@b'), isNotNull);
      expect(Validators.email('a@.com'), isNotNull);
    });
  });

  group('password (P-14: 8+, letter + digit)', () {
    test('enforces length and composition', () {
      expect(Validators.password(''), isNotNull);
      expect(Validators.password('Ab1'), isNotNull);
      expect(Validators.password('abcdefgh'), isNotNull,
          reason: 'letters alone are not enough');
      expect(Validators.password('12345678'), isNotNull,
          reason: 'digits alone are not enough');
      expect(Validators.password('Abcd1234'), isNull);
    });
  });

  group('confirmPassword', () {
    test('must match the original', () {
      expect(Validators.confirmPassword('', 'Abcd1234'), isNotNull);
      expect(Validators.confirmPassword('Abcd1235', 'Abcd1234'), isNotNull);
      expect(Validators.confirmPassword('Abcd1234', 'Abcd1234'), isNull);
    });
  });

  group('name', () {
    test('length and character rules', () {
      expect(Validators.name(''), isNotNull);
      expect(Validators.name('A'), isNotNull);
      expect(Validators.name('Jo3'), isNotNull);
      expect(Validators.name('Jo'), isNull);
      expect(Validators.name('Anne-Marie'), isNull);
    });
  });

  group('dateOfBirth (P-12: past date, age 13+)', () {
    final now = DateTime(2026, 10, 3);

    test('rejects missing, future, and underage', () {
      expect(Validators.dateOfBirth(null, now: now), isNotNull);
      expect(Validators.dateOfBirth(DateTime(2027, 1, 1), now: now),
          isNotNull);
      expect(Validators.dateOfBirth(DateTime(2020, 1, 1), now: now),
          isNotNull);
    });

    test('accepts adults, including edge birthdays', () {
      expect(Validators.dateOfBirth(DateTime(2000, 5, 5), now: now), isNull);
      // Turns 13 exactly today.
      expect(Validators.dateOfBirth(DateTime(2013, 10, 3), now: now), isNull);
      // Still 12 (birthday tomorrow).
      expect(Validators.dateOfBirth(DateTime(2013, 10, 4), now: now),
          isNotNull);
    });
  });

  group('otpCode', () {
    test('exactly 6 digits', () {
      expect(Validators.otpCode(''), isNotNull);
      expect(Validators.otpCode('12345'), isNotNull);
      expect(Validators.otpCode('1234567'), isNotNull);
      expect(Validators.otpCode('12a456'), isNotNull);
      expect(Validators.otpCode('123456'), isNull);
    });
  });

  group('optionalNumber', () {
    test('empty is fine; bounds enforced with comma decimals', () {
      expect(
          Validators.optionalNumber('', min: 30, max: 300, label: 'Weight'),
          isNull);
      expect(
          Validators.optionalNumber('70,5', min: 30, max: 300, label: 'Weight'),
          isNull);
      expect(
          Validators.optionalNumber('abc', min: 30, max: 300, label: 'Weight'),
          isNotNull);
      expect(
          Validators.optionalNumber('20', min: 30, max: 300, label: 'Weight'),
          contains('Weight'));
    });
  });
}
