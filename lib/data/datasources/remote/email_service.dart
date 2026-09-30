import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/config/supabase_config.dart';
import '../../../core/errors/app_exception.dart';

/// Sends OTP emails through the `send-otp` Edge Function, which delivers via
/// the project's Gmail SMTP App Password (server-side secret — the app never
/// touches SMTP credentials; PLANNING §5.1 / DEPLOYMENT.md).
class EmailService {
  EmailService({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  /// Requests a 6-digit code for [email].
  /// [passwordReset] selects the flow purpose (`reset` / `signup`).
  ///
  /// Throws [OtpCooldownException] when the 60 s resend window has not
  /// elapsed, [UnknownAuthException] for SMTP/network failures.
  Future<void> sendOtp({
    required String email,
    required bool passwordReset,
  }) async {
    try {
      await _client.functions.invoke(
        SupabaseConfig.otpFunction,
        body: {
          'action': 'send',
          'email': email,
          'purpose': passwordReset ? 'reset' : 'signup',
        },
      );
    } on FunctionException catch (e) {
      throw mapFunctionError(e);
    } on AuthException {
      throw const UnknownAuthException();
    } catch (_) {
      throw const UnknownAuthException();
    }
  }
}

/// Maps `send-otp` error codes (HTTP body `{"error": "<code>"}`) to the
/// [AppException] hierarchy — UI shows [AppException.message] only.
AppException mapFunctionError(FunctionException e) {
  final code = _errorCode(e);
  return switch (code) {
    'invalid' => const InvalidOtpException(),
    'expired' || 'locked' => const OtpExpiredException(),
    'not_verified' => const InvalidOtpException(),
    'exists' => const EmailAlreadyInUseException(),
    'cooldown' => const OtpCooldownException(),
    _ => const UnknownAuthException(),
  };
}

String _errorCode(FunctionException e) {
  final details = e.details;
  if (details is Map && details['error'] is String) {
    return details['error'] as String;
  }
  if (details is String) {
    final idx = details.indexOf('"error"');
    if (idx >= 0) {
      final tail = details.substring(idx);
      final match = RegExp('"error"\\s*:\\s*"([a-z_]+)"').firstMatch(tail);
      if (match != null) return match.group(1)!;
    }
  }
  return '';
}
