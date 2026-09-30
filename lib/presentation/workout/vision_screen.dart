import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../shared/grid_background.dart';
import 'widgets/framing_guide.dart';
import 'widgets/posture_avatar.dart';
import 'widgets/vision_hud.dart';

/// 10 — Vision screen / live rep counting (sample `index.html`).
///
/// The camera feed is wired in phase P3, so this renders the mock camera area:
/// dark preview with framing guide, skeleton overlay, rep HUD, voice cue and
/// the session controls.
class VisionScreen extends StatefulWidget {
  const VisionScreen({super.key});

  @override
  State<VisionScreen> createState() => _VisionScreenState();
}

class _VisionScreenState extends State<VisionScreen> {
  bool _paused = false;
  bool _mirrored = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: GridBackground(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final width = constraints.maxWidth;
                final height = constraints.maxHeight;
                return ClipRRect(
                  borderRadius: BorderRadius.circular(28),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      const _CameraBackdrop(),
                      const Positioned.fill(child: FramingGuide()),
                      Positioned(
                        left: (width - 170) / 2,
                        top: height * 0.26,
                        child: Transform.flip(
                          flipX: _mirrored,
                          child: SizedBox(
                            width: 170,
                            height: 330,
                            child: CustomPaint(painter: _SkeletonPainter()),
                          ),
                        ),
                      ),
                      const Positioned(
                        top: 16,
                        left: 14,
                        child: VisionHud(
                          reps: _reps,
                          round: _round,
                          time: _time,
                        ),
                      ),
                      const Positioned(
                        top: 16,
                        right: 14,
                        child: PostureAvatar(),
                      ),
                      const Positioned(
                        left: 14,
                        right: 14,
                        bottom: 118,
                        child: _VoiceCue(),
                      ),
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 34,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _CamButton(
                              icon: Icons.cameraswitch,
                              onTap: () =>
                                  setState(() => _mirrored = !_mirrored),
                            ),
                            const SizedBox(width: 16),
                            _CamButton(
                              icon: _paused ? Icons.play_arrow : Icons.pause,
                              main: true,
                              onTap: () => setState(() => _paused = !_paused),
                            ),
                            const SizedBox(width: 16),
                            _CamButton(
                              icon: Icons.stop,
                              danger: true,
                              onTap: () => context.push('/summary'),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

/// Mock camera preview: dark gradient + soft top glow (sample `.cam`).
class _CameraBackdrop extends StatelessWidget {
  const _CameraBackdrop();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [AppColors.lightInk, AppColors.darkPage],
        ),
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: const Alignment(0, -0.4),
            radius: 0.85,
            colors: [
              AppColors.lightInk2.withAlpha(150),
              AppColors.lightInk2.withAlpha(0),
            ],
          ),
        ),
      ),
    );
  }
}

/// Voice-coach banner above the controls (sample `.cue`).
class _VoiceCue extends StatelessWidget {
  const _VoiceCue();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.darkPage.withAlpha(153),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withAlpha(46)),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.accentBright.withAlpha(51),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.volume_up,
              size: 18,
              color: AppColors.accentBright,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _cue,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _cueSub,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: Colors.white.withAlpha(168),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Round glass control under the preview (sample `.cbtn`).
class _CamButton extends StatelessWidget {
  const _CamButton({
    required this.icon,
    required this.onTap,
    this.main = false,
    this.danger = false,
  });

  final IconData icon;
  final VoidCallback onTap;
  final bool main;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final Color background;
    final Color border;
    final Color foreground;
    if (main) {
      background = Colors.white.withAlpha(235);
      border = Colors.white.withAlpha(77);
      foreground = AppColors.lightInk;
    } else if (danger) {
      background = AppColors.danger.withAlpha(217);
      border = Colors.white.withAlpha(77);
      foreground = Colors.white;
    } else {
      background = Colors.white.withAlpha(36);
      border = Colors.white.withAlpha(64);
      foreground = Colors.white;
    }
    final diameter = main ? 64.0 : 56.0;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Container(
          width: diameter,
          height: diameter,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: background,
            shape: BoxShape.circle,
            border: Border.all(color: border),
          ),
          child: Icon(icon, size: main ? 30 : 23, color: foreground),
        ),
      ),
    );
  }
}

/// Tracked-body overlay drawn in the sample's 170 × 330 coordinate space.
class _SkeletonPainter extends CustomPainter {
  static const _bones = <(Offset, Offset)>[
    (Offset(85, 54), Offset(85, 140)),
    (Offset(85, 78), Offset(42, 118)),
    (Offset(85, 78), Offset(128, 118)),
    (Offset(85, 140), Offset(56, 205)),
    (Offset(85, 140), Offset(114, 205)),
    (Offset(56, 205), Offset(50, 278)),
    (Offset(114, 205), Offset(120, 278)),
  ];

  static const _joints = <Offset>[
    Offset(85, 78),
    Offset(42, 118),
    Offset(128, 118),
    Offset(85, 140),
    Offset(56, 205),
    Offset(114, 205),
    Offset(50, 278),
    Offset(120, 278),
  ];

  static const _knees = <Offset>[Offset(56, 205), Offset(114, 205)];

  @override
  void paint(Canvas canvas, Size size) {
    final bone = Paint()
      ..color = AppColors.darkAccentDeep
      ..strokeWidth = 3.5
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    final jointFill = Paint();
    final jointRing = Paint()
      ..color = AppColors.accentInk
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    // Fit the sample artwork (170 × 330) into the given box.
    final scaleX = size.width / 170;
    final scaleY = size.height / 330;
    final scale = scaleX < scaleY ? scaleX : scaleY;
    canvas.translate((size.width - 170 * scale) / 2, 0);
    canvas.scale(scale);

    canvas.drawCircle(const Offset(85, 34), 20, bone);
    for (final (from, to) in _bones) {
      canvas.drawLine(from, to, bone);
    }
    for (final joint in _joints) {
      final knee = _knees.contains(joint);
      jointFill.color = knee
          ? AppColors.darkAccentDeep
          : AppColors.accentBright;
      canvas.drawCircle(joint, knee ? 7 : 6, jointFill);
      canvas.drawCircle(joint, knee ? 7 : 6, jointRing);
    }
  }

  @override
  bool shouldRepaint(covariant _SkeletonPainter oldDelegate) => false;
}

// UI-first demo data — phase P3 wires the real source.
const int _reps = 12;
const String _round = '2 / 3';
const String _time = '04:35';
const String _cue = 'Knees caving in — push your knees outward';
const String _cueSub = 'Keep your chest up · go deeper on the next rep';
