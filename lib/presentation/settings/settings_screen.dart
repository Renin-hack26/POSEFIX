import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/di/app_dependencies.dart';
import '../../core/notification/notification_engine.dart';
import '../../core/storage/hive_service.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/theme_mode_provider.dart';
import '../../data/mappers/session_json.dart';
import '../../domain/entities/user_profile.dart';
import '../../domain/entities/workout_session.dart';
import '../shared/glass_card.dart';
import '../shared/grid_background.dart';

/// Theme choices for the Appearance picker (device-follow by default).
const _themeOptions = [
  ('Auto (device)', ThemeMode.system),
  ('Light', ThemeMode.light),
  ('Dark', ThemeMode.dark),
];

/// Device-local keys for flags not listed among [HiveService]'s constants.
/// The settings box is open key/value storage — these survive restarts.
const String _kReminderMinuteOfDay =
    'reminderMinuteOfDay'; // int — minutes since 00:00
const String _kCoachMuted = 'coachMuted'; // bool — true = spoken cues off

/// Default daily reminder time (07:00) until the user picks one.
const int _defaultReminderMinuteOfDay = 7 * 60;

/// 14 — Settings tab (sample/index.html): profile, preferences, notifications,
/// coach voice, data and account.
///
/// Every row is wired to real behavior:
/// - Appearance → `themeModeProvider` (Hive-backed).
/// - Workout reminders → `NotificationEngine` (permission + daily schedule).
/// - Reminder time → `showTimePicker` + daily reminder reschedule.
/// - Spoken cues → `SoundEngine.setMuted` (Hive-backed).
/// - Export workouts → session history serialized to JSON via share_plus.
/// - Privacy → clears VEDA chat history through `VedaRepository`.
/// - Sign out → `signOutProvider` + redirect to sign-in.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: GridBackground(
        child: SafeArea(
          child: const _SettingsBody(),
        ),
      ),
    );
  }
}

class _SettingsBody extends ConsumerStatefulWidget {
  const _SettingsBody();

  @override
  ConsumerState<_SettingsBody> createState() => _SettingsBodyState();
}

class _SettingsBodyState extends ConsumerState<_SettingsBody> {
  late bool _remindersEnabled =
      HiveService.getBool(HiveService.kNotificationsEnabled);
  late bool _coachMuted = HiveService.getBool(_kCoachMuted);
  UserProfile? _profile;

  @override
  void initState() {
    super.initState();
    // Apply the persisted coach-voice flag to the live engine (real mute API).
    ref.read(soundEngineProvider).setMuted(_coachMuted);
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final user = await ref.read(userRepositoryProvider).currentUser();
    if (!mounted) return;
    setState(() => _profile = user);
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(18, 8, 18, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Settings',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.4,
              color: p.ink,
            ),
          ),
          const SizedBox(height: 16),
          _profileCard(p),
          const SizedBox(height: 20),
          const _SectionLabel('Preferences'),
          const SizedBox(height: 9),
          _appearanceRow(p),
          const SizedBox(height: 20),
          const _SectionLabel('Notifications'),
          const SizedBox(height: 9),
          _LRow(
            icon: Icons.notifications_active,
            title: 'Workout reminders',
            subtitle: 'Daily reminder at your chosen time',
            trailing: Switch(
              value: _remindersEnabled,
              onChanged: _setReminders,
            ),
          ),
          const SizedBox(height: 10),
          _LRow(
            icon: Icons.schedule,
            title: 'Reminder time',
            value: _reminderLabel(),
            onTap: _pickReminderTime,
          ),
          const SizedBox(height: 20),
          const _SectionLabel('Coach voice'),
          const SizedBox(height: 9),
          _LRow(
            icon: Icons.graphic_eq,
            title: 'Spoken cues',
            subtitle: 'Coaching voice and form corrections',
            trailing: Switch(
              value: !_coachMuted,
              onChanged: _setCoachVoice,
            ),
          ),
          const SizedBox(height: 20),
          const _SectionLabel('Data'),
          const SizedBox(height: 9),
          _LRow(
            icon: Icons.ios_share,
            title: 'Export workouts',
            subtitle: 'Share your history as JSON',
            onTap: _exportWorkouts,
          ),
          const SizedBox(height: 10),
          _LRow(
            icon: Icons.shield,
            title: 'Privacy',
            subtitle: 'On-device processing · clear VEDA chat',
            onTap: _clearVedaChat,
          ),
          const SizedBox(height: 20),
          const _SectionLabel('Account'),
          const SizedBox(height: 9),
          _LRow(
            icon: Icons.logout,
            title: 'Sign out',
            danger: true,
            onTap: _signOut,
          ),
          const SizedBox(height: 20),
          Center(
            child: Text(
              'FixPose 1.1.11', // keep in sync with pubspec.yaml version
              style: TextStyle(fontSize: 11.5, color: p.ink3),
            ),
          ),
        ],
      ),
    );
  }

  // --- actions -------------------------------------------------------------

  /// Enables/removes the daily reminder through the NotificationEngine.
  /// Turning it on requests the OS permission first; a denial is honest —
  /// the toggle stays off and the user is told where to unblock it.
  Future<void> _setReminders(bool enabled) async {
    final engine = ref.read(notificationEngineProvider);
    if (enabled) {
      await engine.initialize(); // channels + OS permission request
      final granted = await engine.areNotificationsEnabled();
      if (!mounted) return;
      if (!granted) {
        ScaffoldMessenger.of(context).showSnackBar(_snack(
          'Notifications are blocked — allow them in system settings',
        ));
        return;
      }
      await _scheduleDailyReminder(engine);
    } else {
      await engine.cancelAll();
    }
    await HiveService.setBool(HiveService.kNotificationsEnabled, enabled);
    if (!mounted) return;
    setState(() => _remindersEnabled = enabled);
  }

  Future<void> _scheduleDailyReminder(NotificationEngine engine) async {
    final minuteOfDay =
        HiveService.getInt(_kReminderMinuteOfDay) ?? _defaultReminderMinuteOfDay;
    await engine.scheduleDailyReminder(
      hour: minuteOfDay ~/ 60,
      minute: minuteOfDay % 60,
      workoutName: 'Your workout',
      workoutId: NotificationEngine.settingsReminderWorkoutId,
    );
  }

  Future<void> _pickReminderTime() async {
    final minuteOfDay =
        HiveService.getInt(_kReminderMinuteOfDay) ?? _defaultReminderMinuteOfDay;
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: minuteOfDay ~/ 60, minute: minuteOfDay % 60),
    );
    if (picked == null) return;
    await HiveService.setInt(
        _kReminderMinuteOfDay, picked.hour * 60 + picked.minute);
    if (_remindersEnabled) {
      await _scheduleDailyReminder(ref.read(notificationEngineProvider));
    }
    if (!mounted) return;
    setState(() {});
  }

  String _reminderLabel() {
    final minuteOfDay =
        HiveService.getInt(_kReminderMinuteOfDay) ?? _defaultReminderMinuteOfDay;
    final hour = minuteOfDay ~/ 60;
    final minute = (minuteOfDay % 60).toString().padLeft(2, '0');
    final suffix = hour < 12 ? 'AM' : 'PM';
    final display = hour % 12 == 0 ? 12 : hour % 12;
    return '$display:$minute $suffix';
  }

  /// Coach voice toggle → SoundEngine.setMuted, persisted in Hive.
  void _setCoachVoice(bool spoken) {
    ref.read(soundEngineProvider).setMuted(!spoken);
    HiveService.setBool(_kCoachMuted, !spoken);
    setState(() => _coachMuted = !spoken);
  }

  /// Serializes workout history to JSON and hands the file to the share sheet.
  Future<void> _exportWorkouts() async {
    try {
      final sessions = await ref.read(sessionRepositoryProvider).history();
      final payload = jsonEncode({
        'exportedAt': DateTime.now().toIso8601String(),
        'sessions': [for (final s in sessions) _sessionToJson(s)],
      });
      final dir = await getTemporaryDirectory();
      final stamp = DateTime.now().millisecondsSinceEpoch;
      final file = File('${dir.path}/fixpose_workouts_$stamp.json');
      await file.writeAsString(payload);
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path)],
          text: 'My FixPose workout history',
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(_snack('Export failed — please try again'));
    }
  }

  /// Session → JSON (nested exercises via the shared mappers).
  Map<String, dynamic> _sessionToJson(WorkoutSession s) => {
        'id': s.id,
        'workoutId': s.workoutId,
        'startedAt': s.startedAt.toIso8601String(),
        'endedAt': s.endedAt?.toIso8601String(),
        'status': s.status.name,
        'durationSec': s.durationSec,
        'totalReps': s.totalReps,
        'avgCadenceRpm': s.avgCadenceRpm,
        'formAccuracyPct': s.formAccuracyPct,
        'exercises': [for (final e in s.exercises) exerciseToMap(e)],
      };

  /// Clears VEDA chat history (real repository API) after a confirmation.
  Future<void> _clearVedaChat() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Clear VEDA chat?'),
        content: const Text(
          'This deletes your VEDA conversation history on this device. '
          'It cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Clear'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await ref.read(vedaRepositoryProvider).clearHistory();
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(_snack('VEDA chat history cleared'));
  }

  Future<void> _signOut() async {
    try {
      await ref.read(signOutProvider)();
    } catch (_) {
      // Best effort — the local session may already be cleared.
    }
    if (!mounted) return;
    context.go('/signin');
  }

  SnackBar _snack(String message) => SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
      );

  // --- widgets -------------------------------------------------------------

  /// Profile summary card — real signed-in user (no placeholder identities).
  Widget _profileCard(AppPalette p) {
    final user = _profile;
    final name = user == null
        ? 'Not signed in'
        : (user.fullName.isNotEmpty ? user.fullName : user.email);
    final details = <String>[
      if (user != null) user.email,
      if (user != null) user.gender.label,
      if (user?.weightKg != null) '${user!.weightKg!.round()} kg',
      if (user?.heightCm != null) '${user!.heightCm!.round()} cm',
    ];
    final meta = user == null
        ? 'Sign in to sync your plan and progress'
        : details.join(' · ');
    return GlassCard(
      padding: const EdgeInsets.all(18),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [AppColors.accent, AppColors.accentMid],
              ),
            ),
            child: const Icon(
              Icons.person,
              size: 26,
              color: AppColors.accentInk,
            ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: TextStyle(
                    fontSize: 15.5,
                    fontWeight: FontWeight.w800,
                    color: p.ink,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  meta,
                  style: TextStyle(fontSize: 11.5, color: p.ink3),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Appearance row: Auto (device) / Light / Dark segmented picker, bound to
  /// `themeModeProvider` (the notifier persists the choice in Hive).
  Widget _appearanceRow(AppPalette p) {
    final themeMode = ref.watch(themeModeProvider);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: p.glass,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: p.border, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: p.shadowSoft,
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.dark_mode, size: 20, color: p.ink2),
              const SizedBox(width: 12),
              Text(
                'Appearance',
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w800,
                  color: p.ink,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _Segmented<ThemeMode>(
            options: _themeOptions,
            value: themeMode,
            onChanged: (mode) =>
                ref.read(themeModeProvider.notifier).set(mode),
          ),
        ],
      ),
    );
  }
}

/// Uppercase group heading (sample `.sec > .small` labels).
class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Padding(
      padding: const EdgeInsets.only(bottom: 1),
      child: Text(
        text.toUpperCase(),
        style: TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.7,
          color: p.ink3,
        ),
      ),
    );
  }
}

/// Glass list row (sample `.list .lrow`): icon, title/subtitle, trailing.
class _LRow extends StatelessWidget {
  const _LRow({
    required this.icon,
    required this.title,
    this.subtitle,
    this.value,
    this.trailing,
    this.danger = false,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final String? value;
  final Widget? trailing;
  final bool danger;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final row = Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: p.glass,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: p.border, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: p.shadowSoft,
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: p.ink2),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                    color: danger ? AppColors.danger : p.ink,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle!,
                    style: TextStyle(fontSize: 11.5, color: p.ink3),
                  ),
                ],
              ],
            ),
          ),
          if (value != null) ...[
            const SizedBox(width: 10),
            Text(
              value!,
              style: TextStyle(fontSize: 11.5, color: p.ink3),
            ),
          ],
          if (trailing != null) ...[
            const SizedBox(width: 10),
            trailing!,
          ],
        ],
      ),
    );
    if (onTap == null) return row;
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: Material(
        color: Colors.transparent,
        child: InkWell(onTap: onTap, child: row),
      ),
    );
  }
}

/// Segmented choice (sample `.seg`) over any value type.
class _Segmented<T> extends StatelessWidget {
  const _Segmented({
    required this.options,
    required this.value,
    required this.onChanged,
  });

  final List<(String, T)> options;
  final T value;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: p.segBg,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          for (final (label, option) in options)
            Expanded(
              child: InkWell(
                borderRadius: BorderRadius.circular(11),
                onTap: () => onChanged(option),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 9,
                  ),
                  decoration: option == value
                      ? BoxDecoration(
                          color: p.solid,
                          borderRadius: BorderRadius.circular(11),
                          boxShadow: [
                            BoxShadow(
                              color: p.shadowSoft,
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        )
                      : null,
                  child: Text(
                    label,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: option == value ? p.ink : p.ink2,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
