import '../repositories/user_repository.dart';

/// Re-dispatches the signup OTP for the pending [SignUp] (resend button).
/// Throws when no signup is pending — the screen restarts its countdown
/// only on success.
class ResendOtp {
  const ResendOtp(this._repository);

  final UserRepository _repository;

  Future<OtpDispatch> call() => _repository.resendSignUpOtp();
}
