import '../../domain/entities/user_profile.dart';

/// Result of dispatching an OTP email.
///
/// [devOtp] is only populated by the mock data source (pre-Firebase dev mode)
/// so flows are testable without SMTP. Null once Firebase email is wired.
class OtpDispatch {
  const OtpDispatch({required this.email, this.devOtp});

  final String email;
  final String? devOtp;
}

/// Authentication + profile access contract (domain layer).
///
/// OTP semantics (PLANNING §5.1):
///  - signUp        -> pending account + OTP sent
///  - verifyOtp     -> activates account / proves ownership (signup purpose)
///  - reset flow    -> requestPasswordReset -> verifyOtp -> resetPassword
abstract class UserRepository {
  /// Current signed-in user (null when signed out).
  Future<UserProfile?> currentUser();

  /// Fires on sign-in / sign-out.
  Stream<UserProfile?> authStateChanges();

  /// Creates a pending account and dispatches an OTP to [data.email].
  Future<OtpDispatch> signUp({required SignUpData data, required String password});

  /// Verifies the latest OTP for [email] (signup or password-reset purpose).
  Future<void> verifyOtp({required String email, required String code});

  Future<void> signIn({required String email, required String password});

  /// Sends a password-reset OTP. Throws [UserNotFoundException] if no account.
  Future<OtpDispatch> requestPasswordReset({required String email});

  /// Sets the new password. Requires a verified reset OTP for [email].
  /// Signs the user in on success (auto-redirect home, PLANNING §5.1).
  Future<void> resetPassword({required String email, required String newPassword});

  Future<void> signOut();
}
