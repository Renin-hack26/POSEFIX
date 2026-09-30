import '../entities/user_profile.dart';
import '../repositories/user_repository.dart';

/// Creates a pending account and dispatches the signup OTP email.
/// The account activates only after [VerifyOtp] succeeds.
class SignUp {
  const SignUp(this._repository);

  final UserRepository _repository;

  Future<OtpDispatch> call({
    required SignUpData data,
    required String password,
  }) =>
      _repository.signUp(data: data, password: password);
}
