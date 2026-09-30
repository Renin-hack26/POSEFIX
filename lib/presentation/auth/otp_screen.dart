import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../shared/app_back_button.dart';
import '../shared/grid_background.dart';
import '../shared/primary_button.dart';

/// Where the verified code should land.
enum OtpPurpose { signup, reset }

/// Args passed to (and from) the OTP screen: the destination email + flow.
class OtpArgs {
  const OtpArgs({required this.email, this.purpose = OtpPurpose.signup});

  final String email;
  final OtpPurpose purpose;
}

/// 04 — OTP verification (sample/index.html).
///
/// Spec: the code is NEVER shown on screen — email only, with the exact copy
/// "The code was sent to your email. Check spam if it's missing."
///
/// UI-first: any 6-digit code verifies. P1 checks the real Gmail-sent code
/// (expiry: [AppConstants.otpCodeExpiry], resend: [AppConstants.otpResendCooldown]).
class OtpScreen extends StatefulWidget {
  const OtpScreen({super.key, this.args});

  final OtpArgs? args;

  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> {
  final List<TextEditingController> _digits =
      List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _nodes = List.generate(6, (_) => FocusNode());
  Timer? _timer;
  int _secondsLeft = AppConstants.otpResendCooldown.inSeconds;

  @override
  void initState() {
    super.initState();
    _startCountdown();
  }

  @override
  void dispose() {
    _timer?.cancel();
    for (final c in _digits) {
      c.dispose();
    }
    for (final n in _nodes) {
      n.dispose();
    }
    super.dispose();
  }

  void _startCountdown() {
    _timer?.cancel();
    setState(() => _secondsLeft = AppConstants.otpResendCooldown.inSeconds);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      setState(() {
        _secondsLeft--;
        if (_secondsLeft <= 0) t.cancel();
      });
    });
  }

  void _resend() {
    if (_secondsLeft > 0) return;
    _startCountdown();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('A new code is on its way.')),
    );
  }

  void _onChanged(int index, String value) {
    if (value.isNotEmpty && index < 5) {
      _nodes[index + 1].requestFocus();
    } else if (value.isEmpty && index > 0) {
      _nodes[index - 1].requestFocus();
    }
  }

  void _verify() {
    final code = _digits.map((d) => d.text).join();
    if (code.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter the 6-digit code.')),
      );
      return;
    }
    // UI-first: accepts any 6 digits (P1 validates the emailed code).
    final args = widget.args;
    final purpose = args?.purpose ?? OtpPurpose.signup;
    if (purpose == OtpPurpose.reset) {
      context.push(
        '/reset-password',
        extra: args ?? const OtpArgs(email: ''),
      );
    } else {
      context.go('/home');
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final email = widget.args?.email ?? '';
    final masked =
        email.isEmpty ? 'your registered email' : Formatters.maskEmail(email);

    return Scaffold(
      body: GridBackground(
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24),
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
                      Icons.mail_lock_outlined,
                      size: 36,
                      color: p.accentDeep,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Verification code',
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
                  'We sent a 6-digit code to',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, color: p.ink2),
                ),
                Text(
                  masked,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: p.ink,
                  ),
                ),
                const SizedBox(height: 18),
                // Exact spec copy — do not reword.
                Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: p.glassWeak,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.mark_email_read_outlined,
                        size: 20,
                        color: p.accentDeep,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          "The code was sent to your email. Check spam if it's missing.",
                          style: TextStyle(fontSize: 12.5, color: p.ink2),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    for (var i = 0; i < 6; i++)
                      Expanded(
                        child: Padding(
                          padding: EdgeInsets.only(right: i < 5 ? 9 : 0),
                          child: SizedBox(
                            height: 54,
                            child: TextField(
                              controller: _digits[i],
                              focusNode: _nodes[i],
                              textAlign: TextAlign.center,
                              keyboardType: TextInputType.number,
                              maxLength: 1,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                              ],
                              onChanged: (v) => _onChanged(i, v),
                              style: TextStyle(
                                fontSize: 21,
                                fontWeight: FontWeight.w800,
                                color: p.ink,
                              ),
                              decoration: InputDecoration(
                                counterText: '',
                                contentPadding: EdgeInsets.zero,
                                filled: true,
                                fillColor: p.solid,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(15),
                                  borderSide: BorderSide(
                                    color: p.fieldBorder,
                                    width: 1.5,
                                  ),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(15),
                                  borderSide: BorderSide(
                                    color: p.fieldBorder,
                                    width: 1.5,
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(15),
                                  borderSide: const BorderSide(
                                    color: AppColors.accentMid,
                                    width: 1.8,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 20),
                PrimaryButton(
                  label: 'Verify',
                  icon: Icons.verified_user_outlined,
                  onPressed: _verify,
                ),
                const SizedBox(height: 16),
                Center(
                  child: Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        "Didn't get it? ",
                        style: TextStyle(fontSize: 13.5, color: p.ink2),
                      ),
                      if (_secondsLeft > 0)
                        Text(
                          'Resend in ${Formatters.clock(_secondsLeft)}',
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700,
                            color: p.ink3,
                          ),
                        )
                      else
                        InkWell(
                          onTap: _resend,
                          borderRadius: BorderRadius.circular(8),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 4,
                              vertical: 2,
                            ),
                            child: Text(
                              'Resend code',
                              style: TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w800,
                                color: p.accentDeep,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                Center(
                  child: Text(
                    'Check spam or tap resend — code expires in 10 minutes',
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
    );
  }
}
