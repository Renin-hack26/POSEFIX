import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import 'app_text_field.dart';

/// Password input + live strength meter + rule hint (sample `.strength`/`.hint`).
/// Shared by Sign Up and Reset password.
///
/// Score ≥ 3 = satisfies [Validators.password] (8+ chars, letter + number);
/// the 4th segment rewards extra length/symbols.
class PasswordField extends StatefulWidget {
  const PasswordField({
    super.key,
    required this.label,
    required this.controller,
    this.validator,
    this.onChanged,
    this.onSubmitted,
    this.textInputAction = TextInputAction.next,
    this.autofillHints,
  });

  final String label;
  final TextEditingController controller;
  final String? Function(String?)? validator;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final TextInputAction textInputAction;
  final Iterable<String>? autofillHints;

  @override
  State<PasswordField> createState() => _PasswordFieldState();
}

class _PasswordFieldState extends State<PasswordField> {
  int _score = 0;

  bool get _valid => _score >= 3;

  void _evaluate(String value) {
    var s = 0;
    if (value.length >= 8) s++;
    if (value.contains(RegExp(r'[A-Za-z]'))) s++;
    if (value.contains(RegExp(r'[0-9]'))) s++;
    if (value.length >= 12 || value.contains(RegExp(r'[^A-Za-z0-9]'))) s++;
    setState(() => _score = s);
    widget.onChanged?.call(value);
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppTextField(
          label: widget.label,
          controller: widget.controller,
          obscure: true,
          prefixIcon: Icons.lock_outline,
          validator: widget.validator,
          onChanged: _evaluate,
          onSubmitted: widget.onSubmitted,
          textInputAction: widget.textInputAction,
          autofillHints: widget.autofillHints,
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            for (var i = 0; i < 4; i++)
              Expanded(
                child: Container(
                  height: 5,
                  margin:
                      i < 3 ? const EdgeInsets.only(right: 5) : EdgeInsets.zero,
                  decoration: BoxDecoration(
                    color: i < _score
                        ? (_valid ? AppColors.accentMid : AppColors.amber)
                        : p.track,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 7),
        Row(
          children: [
            Icon(
              _valid ? Icons.check_circle_outline : Icons.info_outline,
              size: 14,
              color: _valid ? p.accentDeep : p.ink3,
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                '8+ characters, letter and number',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: _valid ? p.accentDeep : p.ink3,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
