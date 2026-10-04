import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/config/supabase_config.dart';
import '../../../core/errors/app_exception.dart';
import '../../../domain/entities/user_profile.dart';
import 'email_service.dart';

/// Remote auth operations: Supabase Auth (sessions) plus the `send-otp`
/// Edge Function actions (verify, account creation, password reset).
///
/// The function's service-role keys never touch the app — it only sees the
/// publishable key in the Authorization header (PLANNING §5.1).
class AuthRemoteDataSource {
  AuthRemoteDataSource({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  Future<void> _invoke(Map<String, dynamic> body) async {
    try {
      await _client.functions.invoke(SupabaseConfig.otpFunction, body: body);
    } on FunctionException catch (e) {
      throw mapFunctionError(e);
    } catch (_) {
      throw const UnknownAuthException();
    }
  }

  /// Proves code ownership (row-level check inside the function).
  Future<void> verifyOtp({required String email, required String code}) =>
      _invoke({'action': 'verify', 'email': email, 'code': code});

  /// Whether an account exists — the "User doesn't exist" gate for
  /// sign-in and forgot-password.
  ///
  /// NOTE: `functions.invoke` resolves to [FunctionResponse], not the raw
  /// JSON — reading `.data` is load-bearing. A bare `is Map` check on the
  /// response object is always false and reports every account as missing
  /// (registered users locked out with "User doesn't exist").
  Future<bool> userExists({required String email}) async {
    final res = await _invokeResult(
      {'action': 'check-user', 'email': email},
    );
    final Object? data = res is FunctionResponse ? res.data : res;
    return data is Map && data['exists'] == true;
  }

  /// Creates the account after a verified signup OTP (email pre-confirmed).
  Future<void> createAccount({
    required String email,
    required String password,
    required SignUpData data,
  }) =>
      _invoke({
        'action': 'create-user',
        'email': email,
        'password': password,
        'metadata': {
          'first_name': data.firstName,
          if (data.middleName.isNotEmpty) 'middle_name': data.middleName,
          if (data.lastName.isNotEmpty) 'last_name': data.lastName,
          'date_of_birth': data.dateOfBirth.toIso8601String(),
          'gender': data.gender.wireName,
          if (data.weightKg != null) 'weight_kg': data.weightKg,
          if (data.heightCm != null) 'height_cm': data.heightCm,
        },
      });

  /// Applies the new password (requires a verified reset OTP server-side).
  Future<void> resetPassword({
    required String email,
    required String newPassword,
  }) =>
      _invoke({
        'action': 'reset-password',
        'email': email,
        'password': newPassword,
      });

  Future<dynamic> _invokeResult(Map<String, dynamic> body) async {
    try {
      return await _client.functions.invoke(
        SupabaseConfig.otpFunction,
        body: body,
      );
    } on FunctionException catch (e) {
      throw mapFunctionError(e);
    } catch (_) {
      throw const UnknownAuthException();
    }
  }

  Future<void> signIn({
    required String email,
    required String password,
  }) async {
    try {
      await _client.auth.signInWithPassword(email: email, password: password);
    } on AuthException catch (e) {
      final msg = e.message.toLowerCase();
      if (msg.contains('invalid login')) throw const WrongPasswordException();
      if (msg.contains('rate limit')) throw const UnknownAuthException();
      throw const UnknownAuthException();
    }
  }

  Future<void> signOut() async {
    try {
      await _client.auth.signOut();
    } on AuthException {
      throw const UnknownAuthException();
    }
  }

  UserProfile? currentUser() => _mapUser(_client.auth.currentUser);

  Stream<UserProfile?> authStateChanges() => _client
      .auth
      .onAuthStateChange
      .map((state) => _mapUser(state.session?.user));

  /// Maps a Supabase [User] + metadata (written at create-user) to the
  /// domain [UserProfile].
  UserProfile? _mapUser(User? user) {
    if (user == null) return null;
    final meta = user.userMetadata ?? const <String, dynamic>{};
    String str(String key) {
      final v = meta[key];
      return v is String ? v : '';
    }

    return UserProfile(
      uid: user.id,
      firstName: str('first_name'),
      middleName: str('middle_name'),
      lastName: str('last_name'),
      dateOfBirth:
          DateTime.tryParse(str('date_of_birth')) ?? DateTime(2000, 1, 1),
      gender: genderFromWire(str('gender')),
      email: user.email ?? '',
      weightKg: (meta['weight_kg'] as num?)?.toDouble(),
      heightCm: (meta['height_cm'] as num?)?.toDouble(),
    );
  }
}
