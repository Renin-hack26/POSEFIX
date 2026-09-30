import '../repositories/user_repository.dart';

/// Applies the new password (verified reset OTP required server-side) and
/// signs the user in automatically (PLANNING §5.1: "auto-login → HOME").
class ResetPassword {
  const ResetPassword(this._repository);

  final UserRepository _repository;

  Future<void> call({required String email, required String newPassword}) =>
      _repository.resetPassword(email: email, newPassword: newPassword);
}
