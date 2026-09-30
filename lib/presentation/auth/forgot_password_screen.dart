import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/di/app_dependencies.dart';
import '../../core/errors/app_exception.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/validators.dart';
import '../shared/app_back_button.dart';
import '../shared/app_text_field.dart';
import '../shared/grid_background.dart';
import '../shared/primary_button.dart';
import 'otp_screen.dart';

/// Forgot password — email entry that sends the user into the OTP flow
/// (sample has no dedicated screen; styled after OTP/Reset, PLANNING §5.1).
///
/// P1: checks the account exists first — no account shows the exact spec
/// copy "User doesn't exist" ([UserNotFoundException.message]).
class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() =>
      _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _sendCode() async {
    if (!(_formKey.currentState?.validate() ?? false) || _busy) return;
    setState(() => _busy = true);
    try {
      await ref.read(forgotPasswordProvider)(email: _email.text.trim());
      if (!mounted) return;
      await context.push(
        '/otp',
        extra: OtpArgs(email: _email.text.trim(), purpose: OtpPurpose.reset),
      );
    } on AppException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Scaffold(
      body: GridBackground(
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const AppBackButton(),
                  const SizedBox(height: 22),
                  Center(
                    child: Container(
                      width: 74,
                      height: 74,
                      decoration: BoxDecoration(
                        color: p.accentSoft,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.lock_outline,
                        size: 36,
                        color: p.accentDeep,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Forgot password?',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 23,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.4,
                      color: p.ink,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    "Enter your email and we'll send a 6-digit verification code.",
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 14, color: p.ink2),
                  ),
                  const SizedBox(height: 22),
                  AppTextField(
                    label: 'Email',
                    hint: 'you@example.com',
                    controller: _email,
                    prefixIcon: Icons.mail_outline,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.done,
                    autofillHints: const [AutofillHints.email],
                    validator: Validators.email,
                    onSubmitted: (_) => _sendCode(),
                  ),
                  const SizedBox(height: 20),
                  PrimaryButton(
                    label: 'Send code',
                    icon: Icons.arrow_forward,
                    loading: _busy,
                    onPressed: _sendCode,
                  ),
                  const SizedBox(height: 14),
                  Center(
                    child: Text(
                      'The code expires after 10 minutes',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 11.5, color: p.ink3),
                    ),
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
