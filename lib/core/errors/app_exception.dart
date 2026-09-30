/// FixPose application exceptions — thrown by repositories/usecases.
/// UI maps these to human-readable messages (never show raw errors).
sealed class AppException implements Exception {
  const AppException(this.message);

  final String message;
}

// --- Auth ---
class UserNotFoundException extends AppException {
  const UserNotFoundException() : super("User doesn't exist");
}

class EmailAlreadyInUseException extends AppException {
  const EmailAlreadyInUseException() : super('An account with this email already exists');
}

class WrongPasswordException extends AppException {
  const WrongPasswordException() : super('Incorrect password');
}

class InvalidOtpException extends AppException {
  const InvalidOtpException() : super('Invalid code. Please check and try again');
}

class OtpExpiredException extends AppException {
  const OtpExpiredException() : super('Code expired. Please request a new one');
}

class WeakPasswordException extends AppException {
  const WeakPasswordException() : super('Password is too weak. Use at least 8 characters');
}

class OtpAlreadyVerifiedException extends AppException {
  const OtpAlreadyVerifiedException() : super('Code already used. Request a new one');
}

class UnknownAuthException extends AppException {
  const UnknownAuthException() : super('Something went wrong. Please try again');
}
