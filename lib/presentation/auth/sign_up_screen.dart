import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/di/app_dependencies.dart';
import '../../core/errors/app_exception.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/validators.dart';
import '../../domain/entities/user_profile.dart';
import '../shared/app_back_button.dart';
import '../shared/app_text_field.dart';
import '../shared/grid_background.dart';
import '../shared/password_field.dart';
import '../shared/primary_button.dart';
import 'otp_screen.dart';

/// 03 — Sign Up (sample/index.html). "Step 1 of 1 — your details".
///
/// P1: submit dispatches the signup OTP through the Supabase-backed
/// [SignUp] use case — the account activates only after the OTP screen
/// verifies the emailed code (PLANNING §5.1).
class SignUpScreen extends ConsumerStatefulWidget {
  const SignUpScreen({super.key});

  @override
  ConsumerState<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends ConsumerState<SignUpScreen> {
  final _formKey = GlobalKey<FormState>();
  final _firstName = TextEditingController();
  final _middleName = TextEditingController();
  final _lastName = TextEditingController();
  final _dobText = TextEditingController();
  final _weight = TextEditingController();
  final _height = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirmPassword = TextEditingController();

  DateTime? _dob;
  String? _gender;
  bool _genderError = false;
  bool _busy = false;

  @override
  void dispose() {
    for (final c in [
      _firstName, _middleName, _lastName, _dobText, _weight,
      _height, _email, _password, _confirmPassword,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _pickDob() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dob ?? DateTime(DateTime.now().year - 18),
      firstDate: DateTime(1920),
      lastDate: DateTime.now(),
    );
    if (picked == null || !mounted) return;
    setState(() {
      _dob = picked;
      _dobText.text = Formatters.dateLong(picked);
    });
  }

  Future<void> _submit() async {
    final formOk = _formKey.currentState?.validate() ?? false;
    setState(() => _genderError = _gender == null);
    if (!formOk || _gender == null || _busy) return;
    setState(() => _busy = true);
    try {
      await ref.read(signUpProvider)(
        data: SignUpData(
          firstName: _firstName.text.trim(),
          middleName: _middleName.text.trim(),
          lastName: _lastName.text.trim(),
          dateOfBirth: _dob!,
          gender: Gender.values.firstWhere((g) => g.label == _gender),
          email: _email.text.trim(),
          weightKg: double.tryParse(_weight.text.trim()),
          heightCm: double.tryParse(_height.text.trim()),
        ),
        password: _password.text,
      );
      if (!mounted) return;
      await context.push(
        '/otp',
        extra: OtpArgs(email: _email.text.trim(), purpose: OtpPurpose.signup),
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
                  Row(
                    children: [
                      const AppBackButton(),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Create account',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: p.ink,
                              ),
                            ),
                            Text(
                              'Step 1 of 1 — your details',
                              style:
                                  TextStyle(fontSize: 12, color: p.ink3),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  AppTextField(
                    label: 'First name *',
                    hint: 'Alex',
                    controller: _firstName,
                    prefixIcon: Icons.person_outline,
                    textInputAction: TextInputAction.next,
                    validator: (v) => Validators.name(v, field: 'First name'),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: AppTextField(
                          label: 'Middle name',
                          hint: 'Optional',
                          controller: _middleName,
                          textInputAction: TextInputAction.next,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: AppTextField(
                          label: 'Last name',
                          hint: 'Carter',
                          controller: _lastName,
                          textInputAction: TextInputAction.next,
                          validator: (v) {
                            final s = v?.trim() ?? '';
                            if (s.isEmpty) return null; // optional
                            return Validators.name(v, field: 'Last name');
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  const FieldLabel('Date of birth *'),
                  const SizedBox(height: 7),
                  TextFormField(
                    controller: _dobText,
                    readOnly: true,
                    onTap: _pickDob,
                    validator: (_) => Validators.dateOfBirth(_dob),
                    decoration: InputDecoration(
                      hintText: 'Select your date',
                      prefixIcon: const Icon(Icons.cake_outlined, size: 20),
                      suffixIcon: const Icon(
                        Icons.calendar_month_outlined,
                        size: 20,
                      ),
                      helperText: 'Future dates not allowed · must be 13+',
                      helperStyle: TextStyle(fontSize: 11.5, color: p.ink3),
                    ),
                  ),
                  const SizedBox(height: 14),
                  const FieldLabel('Gender *'),
                  const SizedBox(height: 7),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final option in const [
                        'Male',
                        'Female',
                        'Prefer not to say',
                      ])
                        _GenderPill(
                          label: option,
                          selected: _gender == option,
                          onTap: () => setState(() {
                            _gender = option;
                            _genderError = false;
                          }),
                        ),
                    ],
                  ),
                  if (_genderError) ...[
                    const SizedBox(height: 6),
                    Text(
                      'Gender is required.',
                      style:
                          TextStyle(fontSize: 11.5, color: AppColors.danger),
                    ),
                  ],
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: AppTextField(
                          label: 'Weight (kg)',
                          hint: '72',
                          controller: _weight,
                          prefixIcon: Icons.monitor_weight_outlined,
                          keyboardType: TextInputType.number,
                          validator: (v) => Validators.optionalNumber(
                            v,
                            min: 30,
                            max: 250,
                            label: 'Weight',
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: AppTextField(
                          label: 'Height (cm)',
                          hint: '178',
                          controller: _height,
                          prefixIcon: Icons.straighten_outlined,
                          keyboardType: TextInputType.number,
                          validator: (v) => Validators.optionalNumber(
                            v,
                            min: 100,
                            max: 250,
                            label: 'Height',
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  AppTextField(
                    label: 'Email *',
                    hint: 'you@example.com',
                    controller: _email,
                    prefixIcon: Icons.mail_outline,
                    keyboardType: TextInputType.emailAddress,
                    autofillHints: const [AutofillHints.email],
                    validator: Validators.email,
                  ),
                  const SizedBox(height: 14),
                  PasswordField(
                    label: 'Password *',
                    controller: _password,
                    autofillHints: const [AutofillHints.newPassword],
                    validator: Validators.password,
                  ),
                  const SizedBox(height: 14),
                  AppTextField(
                    label: 'Confirm password *',
                    hint: 'Repeat your password',
                    controller: _confirmPassword,
                    obscure: true,
                    prefixIcon: Icons.lock_reset_outlined,
                    textInputAction: TextInputAction.done,
                    validator: (v) =>
                        Validators.confirmPassword(v, _password.text),
                    onSubmitted: (_) => _submit(),
                  ),
                  const SizedBox(height: 18),
                  PrimaryButton(
                    label: 'Create account',
                    icon: Icons.arrow_forward,
                    loading: _busy,
                    onPressed: _submit,
                  ),
                  const SizedBox(height: 12),
                  Center(
                    child: Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          'Already registered?',
                          style:
                              TextStyle(fontSize: 12.5, color: p.ink3),
                        ),
                        LinkButton(
                          label: 'Sign in',
                          onPressed: () => context.go('/signin'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 28),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Pill toggle for the gender row — each option sizes to its own label and
/// wraps onto the next run instead of squeezing text (segmented button did).
class _GenderPill extends StatelessWidget {
  const _GenderPill({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Material(
      color: selected ? p.selBg : p.track,
      borderRadius: BorderRadius.circular(999),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: selected ? p.selFg : p.ink2,
            ),
          ),
        ),
      ),
    );
  }
}
