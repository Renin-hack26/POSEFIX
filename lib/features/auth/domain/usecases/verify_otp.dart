import '../repositories/user_repository.dart';

/// Verifies the 6-digit OTP for [email].
///
/// Signup purpose: creates + activates the account and signs the user in.
/// Reset purpose: marks ownership proven so [ResetPassword] can proceed.
class VerifyOtp {
  const VerifyOtp(this._repository);

  final UserRepository _repository;

  Future<void> call({required String email, required String code}) =>
      _repository.verifyOtp(email: email, code: code);
}
