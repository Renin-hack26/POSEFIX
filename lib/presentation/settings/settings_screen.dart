import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/theme_mode_provider.dart';
import '../shared/glass_card.dart';
import '../shared/grid_background.dart';

// UI-first toggle — phase P7/P1 wires the real behavior.
const _unitOptions = [('kg · cm', 'metric'), ('lb · ft', 'imperial')];
const _themeOptions = [
  ('Auto (device)', ThemeMode.system),
  ('Light', ThemeMode.light),
  ('Dark', ThemeMode.dark),
];
const _profileName = 'Alex Carter';
const _profileMeta = 'alex.carter@gmail.com · Male · 72 kg · 178 cm';
const _reminderTimes = '07:00 · 17:00';
const _quietHoursRange = '22:00 – 07:00';

/// 14 — Settings tab (sample/index.html): profile, preferences (units,
/// appearance, language), notifications, coach voice, data and account.
///
/// The Appearance picker is bound to `themeModeProvider` — it defaults to
/// "Auto (device)" and follows the device until the user picks a side.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    return Scaffold(
      body: GridBackground(
        child: SafeArea(
          child: _SettingsBody(
            themeMode: themeMode,
            onThemeModeChanged: (mode) =>
                ref.read(themeModeProvider.notifier).set(mode),
          ),
        ),
      ),
    );
  }
}

/// Holds the UI-first toggles (units, reminders, quiet hours) while the
/// Settings screen stays open; the theme choice lives in [themeModeProvider].
class _SettingsBody extends StatefulWidget {
  const _SettingsBody({
    required this.themeMode,
    required this.onThemeModeChanged,
  });

  final ThemeMode themeMode;
  final ValueChanged<ThemeMode> onThemeModeChanged;

  @override
  State<_SettingsBody> createState() => _SettingsBodyState();
}

class _SettingsBodyState extends State<_SettingsBody> {
  String _units = 'metric';
  bool _workoutReminders = true;
  bool _quietHours = true;

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
          _LRow(
            icon: Icons.scale,
            title: 'Units',
            trailing: SizedBox(
              width: 130,
              child: _Segmented<String>(
                options: _unitOptions,
                value: _units,
                onChanged: (value) => setState(() => _units = value),
              ),
            ),
          ),
          const SizedBox(height: 10),
          _appearanceRow(p),
          const SizedBox(height: 10),
          _LRow(
            icon: Icons.translate,
            title: 'Language',
            value: 'English',
            chevron: true,
          ),
          const SizedBox(height: 20),
          const _SectionLabel('Notifications'),
          const SizedBox(height: 9),
          _LRow(
            icon: Icons.notifications_active,
            title: 'Workout reminders',
            subtitle: 'Sent at plan session times',
            trailing: Switch(
              value: _workoutReminders,
              onChanged: (value) =>
                  setState(() => _workoutReminders = value),
            ),
          ),
          const SizedBox(height: 10),
          _LRow(
            icon: Icons.schedule,
            title: "Today's times",
            subtitle: _reminderTimes,
            trailing: const _Chip(label: 'Edit'),
          ),
          const SizedBox(height: 10),
          _LRow(
            icon: Icons.bedtime,
            title: 'Quiet hours',
            subtitle: _quietHoursRange,
            trailing: Switch(
              value: _quietHours,
              onChanged: (value) => setState(() => _quietHours = value),
            ),
          ),
          const SizedBox(height: 20),
          const _SectionLabel('Coach voice'),
          const SizedBox(height: 9),
          _LRow(
            icon: Icons.graphic_eq,
            title: 'Offline voice ready',
            subtitle: 'Voice pack installed — works without internet',
            iconColor: p.accentDeep,
            trailing: Icon(Icons.check_circle, size: 20, color: p.accentDeep),
          ),
          const SizedBox(height: 20),
          const _SectionLabel('Data'),
          const SizedBox(height: 9),
          _LRow(
            icon: Icons.ios_share,
            title: 'Export reports',
            subtitle: 'PDF · CSV',
            chevron: true,
          ),
          const SizedBox(height: 10),
          _LRow(
            icon: Icons.shield,
            title: 'Privacy',
            subtitle: 'On-device processing · clear cache',
            chevron: true,
          ),
          const SizedBox(height: 20),
          const _SectionLabel('Account'),
          const SizedBox(height: 9),
          _LRow(
            icon: Icons.delete,
            title: 'Delete account',
            danger: true,
            chevron: true,
          ),
          const SizedBox(height: 10),
          _LRow(
            icon: Icons.logout,
            title: 'Sign out',
            danger: true,
            chevron: true,
            onTap: () => context.go('/signin'),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  /// Profile summary card (sample profile `.glass.pad.row`).
  Widget _profileCard(AppPalette p) {
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
                  _profileName,
                  style: TextStyle(
                    fontSize: 15.5,
                    fontWeight: FontWeight.w800,
                    color: p.ink,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _profileMeta,
                  style: TextStyle(fontSize: 11.5, color: p.ink3),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          const _Chip(label: 'Edit'),
        ],
      ),
    );
  }

  /// Appearance row: Auto (device) / Light / Dark segmented picker.
  Widget _appearanceRow(AppPalette p) {
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
            value: widget.themeMode,
            onChanged: widget.onThemeModeChanged,
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
    this.iconColor,
    this.chevron = false,
    this.danger = false,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final String? value;
  final Widget? trailing;
  final Color? iconColor;
  final bool chevron;
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
          Icon(icon, size: 20, color: iconColor ?? p.ink2),
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
          if (chevron) ...[
            const SizedBox(width: 4),
            Icon(Icons.chevron_right, size: 20, color: p.ink3),
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

/// Static glass chip (sample `.chip`) — decorative row action.
class _Chip extends StatelessWidget {
  const _Chip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      decoration: BoxDecoration(
        color: p.glassHi,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: p.border, width: 1.2),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12.5,
          fontWeight: FontWeight.w700,
          color: p.ink,
        ),
      ),
    );
  }
}
