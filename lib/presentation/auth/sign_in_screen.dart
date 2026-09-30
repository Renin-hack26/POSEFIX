import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/validators.dart';
import '../shared/app_logo.dart';
import '../shared/app_text_field.dart';
import '../shared/grid_background.dart';
import '../shared/primary_button.dart';

/// 02 — Sign In (sample/index.html).
///
/// UI-first: form + validation are real; submit accepts any valid input and
/// enters the app. P1 swaps `_submit` to the Supabase-backed UserRepository
/// ("user doesn't exist" error etc. — PLANNING §5.1).
class SignInScreen extends StatefulWidget {
  const SignInScreen({super.key});

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    context.go('/home');
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
                  const SizedBox(height: 26),
                  const AppLogo(),
                  const SizedBox(height: 20),
                  Text(
                    'Welcome back',
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.8,
                      color: p.ink,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    'Sign in to continue your training streak.',
                    style: TextStyle(fontSize: 14, color: p.ink2),
                  ),
                  const SizedBox(height: 24),
                  AppTextField(
                    label: 'Email',
                    hint: 'you@example.com',
                    controller: _email,
                    prefixIcon: Icons.mail_outline,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    autofillHints: const [AutofillHints.email],
                    validator: Validators.email,
                  ),
                  const SizedBox(height: 14),
                  AppTextField(
                    label: 'Password',
                    hint: 'Your password',
                    controller: _password,
                    obscure: true,
                    prefixIcon: Icons.lock_outline,
                    textInputAction: TextInputAction.done,
                    autofillHints: const [AutofillHints.password],
                    validator: (v) => Validators.required(v, field: 'Password'),
                    onSubmitted: (_) => _submit(),
                  ),
                  const SizedBox(height: 4),
                  Align(
                    alignment: Alignment.centerRight,
                    child: LinkButton(
                      label: 'Forgot password?',
                      onPressed: () => context.push('/forgot'),
                    ),
                  ),
                  const SizedBox(height: 8),
                  PrimaryButton(
                    label: 'Sign In',
                    icon: Icons.arrow_forward,
                    onPressed: _submit,
                  ),
                  const _OrDivider(),
                  SecondaryButton(
                    label: 'New here? Create account',
                    onPressed: () => context.go('/signup'),
                  ),
                  const SizedBox(height: 18),
                  Center(
                    child: Text(
                      '100% on-device — camera frames never leave your phone',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 11.5, color: p.ink3),
                    ),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// "or" rule between primary and secondary actions (sample `.divider`).
class _OrDivider extends StatelessWidget {
  const _OrDivider();

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 18),
      child: Row(
        children: [
          Expanded(child: Container(height: 1, color: p.line)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              'or',
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                color: p.ink3,
              ),
            ),
          ),
          Expanded(child: Container(height: 1, color: p.line)),
        ],
      ),
    );
  }
}
