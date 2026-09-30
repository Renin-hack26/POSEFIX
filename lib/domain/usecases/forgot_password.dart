import '../repositories/user_repository.dart';

/// Sends a password-reset OTP.
/// Throws `UserNotFoundException` ("User doesn't exist") when no account
/// matches the email (PLANNING §5.1).
class ForgotPassword {
  const ForgotPassword(this._repository);

  final UserRepository _repository;

  Future<OtpDispatch> call({required String email}) =>
      _repository.requestPasswordReset(email: email);
}
