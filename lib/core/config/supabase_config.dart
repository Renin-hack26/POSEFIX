/// Supabase project configuration — safe to bundle in the app.
///
/// Only publishable values live here (PLANNING §5.1): the project URL and the
/// publishable (anon-equivalent) key. Secrets — Gmail App Password, service
/// role key, access tokens — stay in `secrets/local.env` + Supabase secrets
/// and are used exclusively by the `send-otp` Edge Function.
abstract final class SupabaseConfig {
  static const url = 'https://tobxphhtgytovohuhjvn.supabase.co';
  static const publishableKey =
      'sb_publishable_yGjfrfkio0GRE5f-Pa8nLQ_bnEibv7w';

  /// Edge function handling OTP send/verify + account lifecycle actions.
  static const otpFunction = 'send-otp';
}
