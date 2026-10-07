import '../repositories/user_repository.dart';

/// Ends the current session (Settings → Sign out).
class SignOut {
  const SignOut(this._repository);

  final UserRepository _repository;

  Future<void> call() => _repository.signOut();
}
