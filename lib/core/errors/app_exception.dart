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

class OtpCooldownException extends AppException {
  const OtpCooldownException() : super('Please wait a moment before resending');
}

class UnknownAuthException extends AppException {
  const UnknownAuthException() : super('Something went wrong. Please try again');
}

// --- Data / sync ---
class StorageException extends AppException {
  const StorageException(
      [super.message = 'Local storage error. Please try again']);
}

class SyncException extends AppException {
  const SyncException([super.message = 'Could not reach the server. Your data is safe on this device']);
}

class NetworkException extends AppException {
  const NetworkException([super.message = "You're offline — working from local data"]);
}

// --- VEDA ---
class VedaUnavailableException extends AppException {
  const VedaUnavailableException(
      [super.message = "VEDA can't reach its assistant right now — check your connection"]);
}
