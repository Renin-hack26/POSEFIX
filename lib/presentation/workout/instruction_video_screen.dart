import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../shared/glass_card.dart';
import '../shared/grid_background.dart';
import '../shared/primary_button.dart';
import '../shared/status_pill.dart';
import '../shared/under_construction_banner.dart';

/// 09 — Instruction video (sample `index.html`): form-demo player, coaching
/// steps and the hand-off into the live camera session.
class InstructionVideoScreen extends StatelessWidget {
  const InstructionVideoScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Scaffold(
      body: GridBackground(
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.only(bottom: 26),
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(left: 20, top: 8),
                    child: Material(
                      color: p.glass,
                      borderRadius: BorderRadius.circular(14),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(14),
                        onTap: () => context.canPop()
                            ? context.pop()
                            : context.go('/workout'),
                        child: const SizedBox(
                          width: 42,
                          height: 42,
                          child: Icon(Icons.close, size: 21),
                        ),
                      ),
                    ),
                  ),
                  const Expanded(
                    child: Center(
                      child: StatusPill(
                        label: 'First time · watch form demo',
                        dot: false,
                      ),
                    ),
                  ),
                  const _VolumeButton(),
                ],
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 14),
                    const UnderConstructionBanner(),
                    const SizedBox(height: 12),
                    Stack(
                      children: [
                        Container(
                          height: 220,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [AppColors.lightInk2, AppColors.lightInk],
                            ),
                            borderRadius: BorderRadius.circular(24),
                          ),
                          child: const Center(child: _PlayButton()),
                        ),
                        const Positioned(
                          left: 10,
                          bottom: 10,
                          child: _VideoCaption(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Barbell Squat',
                      style: TextStyle(
                        fontSize: 21,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.4,
                        color: p.ink,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Round 1 of 3 · 12 reps · full ROM below 90°',
                      style: TextStyle(fontSize: 13, color: p.ink2),
                    ),
                    const SizedBox(height: 20),
                    for (final (index, step) in _steps.indexed) ...[
                      _StepRow(index: index + 1, step: step),
                      const SizedBox(height: 10),
                    ],
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: SecondaryButton(
                            label: 'Skip demo',
                            onPressed: () => context.push('/vision'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: PrimaryButton(
                            label: 'Next — open camera',
                            icon: Icons.photo_camera,
                            onPressed: () => context.push('/vision'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Numbered coaching step (sample `.lrow` without a thumb).
class _StepRow extends StatelessWidget {
  const _StepRow({required this.index, required this.step});

  final int index;
  final (String, String) step;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return GlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      radius: 18,
      child: Row(
        children: [
          Container(
            width: 26,
            height: 26,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: p.selBg,
              borderRadius: BorderRadius.circular(9),
            ),
            child: Text(
              '$index',
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w800,
                color: p.selFg,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  step.$1,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: p.ink,
                  ),
                ),
                const SizedBox(height: 2),
                Text(step.$2, style: TextStyle(fontSize: 11.5, color: p.ink3)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Big round play/pause control on the demo video (sample `.icon-btn.round`).
class _PlayButton extends StatefulWidget {
  const _PlayButton();

  @override
  State<_PlayButton> createState() => _PlayButtonState();
}

class _PlayButtonState extends State<_PlayButton> {
  bool _playing = false;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withAlpha(235),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: () => setState(() => _playing = !_playing),
        child: SizedBox(
          width: 62,
          height: 62,
          child: Icon(
            _playing ? Icons.pause : Icons.play_arrow,
            size: 30,
            color: AppColors.lightInk,
          ),
        ),
      ),
    );
  }
}

/// Bottom-left title/length pill on the demo video (sample `.cap pill dark`).
class _VideoCaption extends StatelessWidget {
  const _VideoCaption();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.darkPage.withAlpha(199),
        borderRadius: BorderRadius.circular(999),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.smart_display, size: 13, color: Colors.white),
          SizedBox(width: 5),
          Text(
            'Squat — proper form · 0:34',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

/// Speaker toggle in the header (sample `.icon-btn` volume).
class _VolumeButton extends StatefulWidget {
  const _VolumeButton();

  @override
  State<_VolumeButton> createState() => _VolumeButtonState();
}

class _VolumeButtonState extends State<_VolumeButton> {
  bool _on = true;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Padding(
      padding: const EdgeInsets.only(right: 18, top: 8),
      child: Material(
        color: p.glass,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => setState(() => _on = !_on),
          child: SizedBox(
            width: 42,
            height: 42,
            child: Icon(
              _on ? Icons.volume_up : Icons.volume_off,
              size: 21,
              color: p.ink,
            ),
          ),
        ),
      ),
    );
  }
}

// UI-first demo data — phase P3 wires the real source.
const List<(String, String)> _steps = [
  (
    'Feet shoulder-width, toes slightly out',
    'Brace your core before descending',
  ),
  ('Sit back and down until hips pass 90°', 'Keep chest up, spine neutral'),
  ('Drive through heels to stand', 'Knees track over toes — never cave in'),
];
