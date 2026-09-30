import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/di/app_dependencies.dart';
import '../../core/permissions/permission_flow.dart';
import '../../core/theme/app_theme.dart';
import '../shared/app_back_button.dart';
import '../shared/app_logo.dart';
import '../shared/glass_card.dart';
import '../shared/grid_background.dart';
import '../shared/primary_button.dart';

/// First-install permission rationale (PLANNING §6): shown once after splash,
/// before the auth stack. Denials are fine — the camera is re-requested when
/// a workout actually starts.
class PermissionScreen extends ConsumerStatefulWidget {
  const PermissionScreen({super.key});

  @override
  ConsumerState<PermissionScreen> createState() => _PermissionScreenState();
}

class _PermissionScreenState extends ConsumerState<PermissionScreen> {
  bool _busy = false;

  static const _rows = <({IconData icon, String title, String body})>[
    (
      icon: Icons.camera_alt_outlined,
      title: 'Camera',
      body:
          'Tracks your pose during workouts. Video is processed on this phone '
              'and never uploaded.',
    ),
    (
      icon: Icons.notifications_outlined,
      title: 'Notifications',
      body: 'Workout reminders at your planned session times.',
    ),
    (
      icon: Icons.sd_storage_outlined,
      title: 'Storage',
      body: 'Saves reports and exports on this device.',
    ),
  ];

  Future<void> _continue() async {
    setState(() => _busy = true);
    await PermissionFlow.requestAll();
    if (!mounted) return;
    var signedIn = false;
    try {
      signedIn = await ref.read(userRepositoryProvider).currentUser() != null;
    } catch (_) {
      signedIn = false; // auth stack unavailable → route to sign-in
    }
    if (!mounted) return;
    context.go(signedIn ? '/onboarding' : '/signin');
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Scaffold(
      body: GridBackground(
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    AppBackButton(),
                    Spacer(),
                  ],
                ),
                const SizedBox(height: 14),
                const Center(child: AppLogo(size: 64, radius: 20, iconSize: 32)),
                const SizedBox(height: 18),
                Center(
                  child: Text(
                    'Before we start',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 25,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.7,
                      color: p.ink,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 320),
                    child: Text(
                      'FixPose needs these to coach you, remind you and keep '
                          'your results. All pose processing stays on-device.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 13.5, height: 1.45, color: p.ink2),
                    ),
                  ),
                ),
                const SizedBox(height: 22),
                GlassCard(
                  padding: const EdgeInsets.all(6),
                  child: Column(
                    children: [
                      for (var i = 0; i < _rows.length; i++) ...[
                        if (i > 0)
                          Divider(height: 1, thickness: 1, color: p.line),
                        _PermissionRow(row: _rows[i]),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 22),
                PrimaryButton(
                  label: 'Continue',
                  icon: Icons.arrow_forward,
                  loading: _busy,
                  onPressed: _busy ? null : _continue,
                ),
                const SizedBox(height: 8),
                Center(
                  child: Text(
                    'You can change these later in Android settings.',
                    style: TextStyle(fontSize: 11.5, color: p.ink3),
                  ),
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PermissionRow extends StatelessWidget {
  const _PermissionRow({required this.row});

  final ({IconData icon, String title, String body}) row;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: p.glassHi,
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(row.icon, size: 20, color: p.accentDeep),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  row.title,
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w800,
                    color: p.ink,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  row.body,
                  style: TextStyle(fontSize: 12.5, height: 1.4, color: p.ink2),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
