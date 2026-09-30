import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/di/app_dependencies.dart';
import '../../core/errors/app_exception.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/validators.dart';
import '../shared/app_back_button.dart';
import '../shared/app_text_field.dart';
import '../shared/glass_card.dart';
import '../shared/grid_background.dart';
import '../shared/password_field.dart';
import '../shared/primary_button.dart';
import 'otp_screen.dart';

/// 05 — Reset password (sample/index.html).
///
/// P1: applies the new password through [ResetPassword] — the use case also
/// signs the user in (spec copy: "You will be signed in automatically"), then
/// the router lands on HOME.
class ResetPasswordScreen extends ConsumerStatefulWidget {
  const ResetPasswordScreen({super.key, this.args});

  final OtpArgs? args;

  @override
  ConsumerState<ResetPasswordScreen> createState() =>
      _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends ConsumerState<ResetPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false) || _busy) return;
    setState(() => _busy = true);
    try {
      await ref.read(resetPasswordProvider)(
        email: widget.args?.email ?? '',
        newPassword: _password.text,
      );
      if (!mounted) return;
      context.go('/home');
    } on AppException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  bool get _ruleLength => _password.text.length >= 8;
  bool get _ruleMixed =>
      _password.text.contains(RegExp(r'[A-Za-z]')) &&
      _password.text.contains(RegExp(r'[0-9]'));
  bool get _ruleMatch =>
      _confirm.text.isNotEmpty && _confirm.text == _password.text;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final email = widget.args?.email ?? '';
    final masked =
        email.isEmpty ? 'your account' : Formatters.maskEmail(email);

    return Scaffold(
      body: GridBackground(
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Form(
              key: _formKey,
              onChanged: () => setState(() {}), // re-evaluate checklist
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
                        Icons.password_outlined,
                        size: 36,
                        color: p.accentDeep,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Set new password',
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
                    'Ownership verified for $masked',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 14, color: p.ink2),
                  ),
                  const SizedBox(height: 20),
                  PasswordField(
                    label: 'New password',
                    controller: _password,
                    autofillHints: const [AutofillHints.newPassword],
                    textInputAction: TextInputAction.next,
                    validator: Validators.password,
                  ),
                  const SizedBox(height: 14),
                  AppTextField(
                    label: 'Confirm new password',
                    hint: 'Repeat your password',
                    controller: _confirm,
                    obscure: true,
                    prefixIcon: Icons.lock_reset_outlined,
                    textInputAction: TextInputAction.done,
                    validator: (v) =>
                        Validators.confirmPassword(v, _password.text),
                    onSubmitted: (_) => _save(),
                  ),
                  const SizedBox(height: 16),
                  GlassCard(
                    weak: true,
                    radius: 18,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 15,
                      vertical: 13,
                    ),
                    shadow: false,
                    child: Column(
                      children: [
                        _RuleRow(
                          met: _ruleLength,
                          label: 'At least 8 characters',
                        ),
                        const SizedBox(height: 8),
                        _RuleRow(
                          met: _ruleMixed,
                          label: 'Contains a letter and a number',
                        ),
                        const SizedBox(height: 8),
                        _RuleRow(met: _ruleMatch, label: 'Both fields match'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  PrimaryButton(
                    label: 'Save password & continue',
                    icon: Icons.arrow_forward,
                    loading: _busy,
                    onPressed: _save,
                  ),
                  const SizedBox(height: 12),
                  Center(
                    child: Text(
                      'You will be signed in automatically',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 11.5, color: p.ink3),
                    ),
                  ),
                  const SizedBox(height: 30),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Single checklist row — accent when satisfied, muted otherwise.
class _RuleRow extends StatelessWidget {
  const _RuleRow({required this.met, required this.label});

  final bool met;
  final String label;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Row(
      children: [
        Icon(
          met ? Icons.check_circle_outline : Icons.radio_button_unchecked,
          size: 16,
          color: met ? p.accentDeep : p.ink3,
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
            color: met ? p.accentDeep : p.ink3,
          ),
        ),
      ],
    );
  }
}
