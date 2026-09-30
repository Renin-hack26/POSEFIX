import '../repositories/user_repository.dart';

/// Signs in with email + password.
/// Throws [WrongPasswordException] / [UserNotFoundException] subclasses of
/// [AppException] for the UI to render (core/errors/app_exception.dart).
class SignIn {
  const SignIn(this._repository);

  final UserRepository _repository;

  Future<void> call({required String email, required String password}) =>
      _repository.signIn(email: email, password: password);
}
