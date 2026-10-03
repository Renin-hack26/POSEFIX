import '../../core/errors/app_exception.dart';
import '../../domain/entities/user_profile.dart';
import '../../domain/repositories/user_repository.dart';
import '../datasources/remote/auth_remote_data_source.dart';
import '../datasources/remote/email_service.dart';

/// Supabase-backed [UserRepository] (PLANNING §5.1).
///
/// Signup keeps the pending [SignUpData] + password in memory until the OTP
/// is verified; [verifyOtp] then creates the account, activates it and signs
/// the user in. Reset flow verifies → [resetPassword] applies the new
/// password and auto-signs-in (spec: "auto-login → HOME").
class UserRepositoryImpl implements UserRepository {
  UserRepositoryImpl(this._remote, this._email);

  final AuthRemoteDataSource _remote;
  final EmailService _email;

  _PendingSignUp? _pendingSignUp;

  @override
  Future<UserProfile?> currentUser() async => _remote.currentUser();

  @override
  Stream<UserProfile?> authStateChanges() => _remote.authStateChanges();

  @override
  Future<OtpDispatch> signUp({
    required SignUpData data,
    required String password,
  }) async {
    await _email.sendOtp(email: data.email, passwordReset: false);
    _pendingSignUp = _PendingSignUp(data: data, password: password);
    return OtpDispatch(email: data.email);
  }

  @override
  Future<OtpDispatch> resendSignUpOtp() async {
    final pending = _pendingSignUp;
    if (pending == null) throw const UnknownAuthException();
    await _email.sendOtp(email: pending.data.email, passwordReset: false);
    return OtpDispatch(email: pending.data.email);
  }

  @override
  Future<void> verifyOtp({
    required String email,
    required String code,
  }) async {
    await _remote.verifyOtp(email: email, code: code);
    final pending = _pendingSignUp;
    if (pending != null && pending.data.email == email) {
      await _remote.createAccount(
        email: email,
        password: pending.password,
        data: pending.data,
      );
      await _remote.signIn(email: email, password: pending.password);
      _pendingSignUp = null;
    }
  }

  @override
  Future<void> signIn({
    required String email,
    required String password,
  }) async {
    // P1 "User doesn't exist": Supabase answers "Invalid login
    // credentials" for unknown emails and wrong passwords alike, so the
    // existence gate (same `check-user` as the forgot flow) runs first —
    // unknown emails get the honest message instead of "Incorrect password".
    if (!await _remote.userExists(email: email)) {
      throw const UserNotFoundException();
    }
    await _remote.signIn(email: email, password: password);
  }

  @override
  Future<OtpDispatch> requestPasswordReset({required String email}) async {
    if (!await _remote.userExists(email: email)) {
      throw const UserNotFoundException();
    }
    await _email.sendOtp(email: email, passwordReset: true);
    return OtpDispatch(email: email);
  }

  @override
  Future<void> resetPassword({
    required String email,
    required String newPassword,
  }) async {
    await _remote.resetPassword(email: email, newPassword: newPassword);
    // Auto-login after reset (PLANNING §5.1: "Set New Password → auto-login").
    await _remote.signIn(email: email, password: newPassword);
  }

  @override
  Future<void> signOut() => _remote.signOut();
}

class _PendingSignUp {
  const _PendingSignUp({required this.data, required this.password});

  final SignUpData data;
  final String password;
}
