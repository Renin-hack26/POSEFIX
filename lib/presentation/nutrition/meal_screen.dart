import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/di/app_dependencies.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/extensions.dart';
import '../../core/utils/id_gen.dart';
import '../../domain/entities/meal.dart';
import '../../domain/usecases/estimate_meal_calories.dart';
import '../shared/app_back_button.dart';
import '../shared/glass_card.dart';
import '../shared/grid_background.dart';
import '../shared/primary_button.dart';

/// Meal page — free-text AI calorie logging: describe the meal, the model
/// estimates calories (manual entry fallback), pick date/time (default now),
/// meal tag auto-derived from the clock and overridable, save to the log.
class MealScreen extends ConsumerStatefulWidget {
  const MealScreen({super.key});

  @override
  ConsumerState<MealScreen> createState() => _MealScreenState();
}

class _MealScreenState extends ConsumerState<MealScreen> {
  final _desc = TextEditingController();
  final _name = TextEditingController();
  final _calories = TextEditingController();

  DateTime _at = DateTime.now();
  MealType _tag = MealTypeX.forTime(DateTime.now());
  bool _tagTouched = false;

  MealEstimate? _estimate;
  bool _estimating = false;
  bool _saving = false;

  Future<(List<MealEntry>, MealTarget?)>? _today;

  @override
  void initState() {
    super.initState();
    _today = _loadToday();
  }

  @override
  void dispose() {
    _desc.dispose();
    _name.dispose();
    _calories.dispose();
    super.dispose();
  }

  Future<(List<MealEntry>, MealTarget?)> _loadToday() async {
    final repo = ref.read(nutritionRepositoryProvider);
    final entries = await repo.entriesFor(DateTime.now().dateKey);
    final target = await repo.target();
    return (entries, target);
  }

  void _reloadToday() {
    final next = _loadToday(); // start the load *outside* setState
    setState(() {
      _today = next; // block body → setState gets null, not the Future
    });
  }

  /// Edit (or first-time set) the daily calorie target — surfaced as the
  /// "Target N kcal / Set" row in the Today card.
  Future<void> _editTarget(MealTarget? current) async {
    final controller = TextEditingController(
      text: current == null ? '' : '${current.dailyCalories}',
    );
    final value = await showDialog<int>(
      context: context,
      builder: (ctx) {
        var error = '';
        return StatefulBuilder(
          builder: (ctx, setDialogState) => AlertDialog(
            title: const Text('Daily calorie target'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: controller,
                  autofocus: true,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(hintText: 'e.g. 2000'),
                ),
                if (error.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      error,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.redAccent,
                      ),
                    ),
                  ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () {
                  final v = int.tryParse(controller.text.trim());
                  if (v == null || v < 500 || v > 10000) {
                    setDialogState(() => error = 'Enter 500-10000 kcal.');
                    return;
                  }
                  Navigator.pop(ctx, v);
                },
                child: const Text('Save'),
              ),
            ],
          ),
        );
      },
    );
    if (value == null || !mounted) return;
    await ref
        .read(nutritionRepositoryProvider)
        .saveTarget(MealTarget(dailyCalories: value));
    ref.read(mealsRevisionProvider.notifier).bump();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Daily target: $value kcal')),
    );
    _reloadToday();
  }

  // --- actions -----------------------------------------------------------

  Future<void> _estimateCals() async {
    if (_desc.text.trim().isEmpty || _estimating) return;
    setState(() => _estimating = true);
    try {
      final est = await ref
          .read(estimateMealCaloriesProvider)
          .call(_desc.text, at: _at);
      if (!mounted) return;
      if (est == null) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content:
                Text('AI estimate unavailable — enter the calories manually')));
      } else {
        setState(() {
          _estimate = est;
          _name.text = est.name;
          _calories.text = '${est.calories}';
        });
      }
    } finally {
      if (mounted) setState(() => _estimating = false);
    }
  }

  Future<void> _pickAt() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _at,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_at),
    );
    if (time == null) return;
    final next = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    setState(() {
      _at = next;
      // Re-derive the tag from the clock until the user picks one by hand.
      if (!_tagTouched) _tag = MealTypeX.forTime(next);
    });
  }

  Future<void> _save() async {
    final calories = int.tryParse(_calories.text.trim()) ?? 0;
    var name = _name.text.trim();
    if (name.isEmpty) name = _desc.text.trim();
    if (calories < 1 || calories > 5000 || name.isEmpty || _saving) return;
    setState(() => _saving = true);
    try {
      await ref.read(nutritionRepositoryProvider).addEntry(MealEntry(
            id: newId(),
            dateKey: _at.dateKey,
            name: name,
            calories: calories,
            mealType: _tag,
            timeMillis: _at.millisecondsSinceEpoch,
          ));
      // Let Plan (and any other meal consumer) reload its one-shot snapshot.
      ref.read(mealsRevisionProvider.notifier).bump();
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Meal logged — $calories kcal')));
      // Reset the form for a possible next entry; keep it on this page.
      setState(() {
        _desc.clear();
        _name.clear();
        _calories.clear();
        _estimate = null;
        _at = DateTime.now();
        _tagTouched = false;
        _tag = MealTypeX.forTime(_at);
      });
      _reloadToday();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  // --- UI ----------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Scaffold(
      body: GridBackground(
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 10, 18, 4),
                child: Row(
                  children: [
                    const AppBackButton(fallback: '/plan'),
                    Expanded(
                      child: Text(
                        'Log a meal',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: p.ink,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'View log',
                      onPressed: () => context.push('/log'),
                      icon: Icon(Icons.list_alt, size: 21, color: p.ink),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(18, 12, 18, 24),
                  children: [
                    _todayCard(p),
                    const SizedBox(height: 14),
                    _formCard(p),
                    const SizedBox(height: 14),
                    _todayListCard(p),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _todayCard(AppPalette p) => FutureBuilder(
        future: _today,
        builder: (context, snap) {
          final entries = snap.data?.$1;
          final target = snap.data?.$2;
          final eaten =
              (entries ?? []).fold<int>(0, (sum, e) => sum + e.calories);
          return GlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Today',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: p.ink3,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  target == null
                      ? '$eaten kcal logged'
                      : '$eaten / ${target.dailyCalories} kcal',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: p.ink,
                  ),
                ),
                const SizedBox(height: 6),
                InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: () => _editTarget(target),
                  child: Row(
                    children: [
                      Icon(Icons.flag_outlined, size: 14, color: p.ink3),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          target == null
                              ? 'Set daily calorie target'
                              : 'Target ${target.dailyCalories} kcal',
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 12, color: p.ink2),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        target == null ? 'Set' : 'Change',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: p.accentDeep,
                        ),
                      ),
                    ],
                  ),
                ),
                if (target != null) ...[
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(99),
                    child: LinearProgressIndicator(
                      value: target.dailyCalories <= 0
                          ? 0
                          : (eaten / target.dailyCalories).clamp(0.0, 1.0),
                      minHeight: 7,
                      backgroundColor: p.track,
                      color: p.accentDeep,
                    ),
                  ),
                ],
              ],
            ),
          );
        },
      );

  Widget _formCard(AppPalette p) {
    final kcal = int.tryParse(_calories.text.trim()) ?? 0;
    final hasName =
        _name.text.trim().isNotEmpty || _desc.text.trim().isNotEmpty;
    final canSave = hasName && kcal >= 1 && kcal <= 5000;
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'What did you eat?',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: p.ink,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _desc,
            minLines: 1,
            maxLines: 2,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              hintText: 'e.g. "2 rotis and dal with a glass of milk"',
              hintStyle: TextStyle(color: p.ink3, fontSize: 13.5),
              filled: true,
              fillColor: p.fieldInset,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: p.fieldBorder),
              ),
            ),
          ),
          const SizedBox(height: 12),
          PrimaryButton(
            label: 'Estimate calories with AI',
            icon: Icons.auto_awesome,
            loading: _estimating,
            onPressed: _desc.text.trim().isEmpty ? null : _estimateCals,
          ),
          if (_estimate != null) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: p.accentSoft,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  Icon(Icons.auto_awesome, size: 16, color: p.accentDeep),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _estimate!.name,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: p.ink,
                      ),
                    ),
                  ),
                  Text(
                    '${_estimate!.calories} kcal',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: p.accentDeep,
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _name,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    hintText: 'Meal name',
                    hintStyle: TextStyle(color: p.ink3, fontSize: 13.5),
                    filled: true,
                    fillColor: p.fieldInset,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(color: p.fieldBorder),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(
                width: 110,
                child: TextField(
                  controller: _calories,
                  keyboardType: TextInputType.number,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    hintText: 'kcal',
                    hintStyle: TextStyle(color: p.ink3, fontSize: 13.5),
                    filled: true,
                    fillColor: p.fieldInset,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(color: p.fieldBorder),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          InkWell(
            onTap: _pickAt,
            borderRadius: BorderRadius.circular(14),
            child: Container(
              width: double.infinity,
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              decoration: BoxDecoration(
                color: p.fieldInset,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: p.fieldBorder),
              ),
              child: Row(
                children: [
                  Icon(Icons.schedule, size: 17, color: p.ink2),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${DateFormat('EEE, d MMM yyyy').format(_at)} · '
                      '${DateFormat('h:mm a').format(_at)}',
                      style: TextStyle(fontSize: 13, color: p.ink),
                    ),
                  ),
                  Text(
                    'Change',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800,
                      color: p.accentDeep,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final t in MealType.values)
                ChoiceChip(
                  label: Text(t.label),
                  selected: _tag == t,
                  onSelected: (_) => setState(() {
                    _tag = t;
                    _tagTouched = true;
                  }),
                  selectedColor: p.selBg,
                  labelStyle: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: _tag == t ? p.selFg : p.ink2,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          PrimaryButton(
            label: 'Save meal',
            icon: Icons.check,
            loading: _saving,
            onPressed: canSave ? _save : null,
          ),
        ],
      ),
    );
  }

  Widget _todayListCard(AppPalette p) => FutureBuilder(
        future: _today,
        builder: (context, snap) {
          final entries = snap.data?.$1 ?? const <MealEntry>[];
          return GlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Today's meals",
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: p.ink,
                  ),
                ),
                const SizedBox(height: 8),
                if (snap.hasError)
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Couldn\u2019t load today\u2019s meals. '
                          'Your entries are safe — retry to reload.',
                          style:
                              TextStyle(fontSize: 12.5, color: p.ink2),
                        ),
                      ),
                      TextButton(
                        onPressed: _reloadToday,
                        child: const Text('Retry'),
                      ),
                    ],
                  )
                else if (entries.isEmpty)
                  Text(
                    'Nothing logged yet today.',
                    style: TextStyle(fontSize: 12.5, color: p.ink3),
                  )
                else
                  for (final e in entries) ...[
                    Row(
                      children: [
                        Icon(_mealIcon(e.mealType),
                            size: 17, color: p.ink2),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            e.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 13, color: p.ink),
                          ),
                        ),
                        if (e.time != null)
                          Text(
                            DateFormat('h:mm a').format(e.time!),
                            style: TextStyle(fontSize: 11.5, color: p.ink3),
                          ),
                        const SizedBox(width: 10),
                        Text(
                          '${e.calories} kcal',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: p.ink,
                          ),
                        ),
                        IconButton(
                          tooltip: 'Remove',
                          visualDensity: VisualDensity.compact,
                          icon: Icon(Icons.close,
                              size: 16, color: p.ink3),
                          onPressed: () async {
                            await ref
                                .read(nutritionRepositoryProvider)
                                .removeEntry(e.id);
                            ref.read(mealsRevisionProvider.notifier).bump();
                            if (mounted) _reloadToday();
                          },
                        ),
                      ],
                    ),
                    if (e != entries.last)
                      Divider(height: 14, color: p.line, thickness: 0.6),
                  ],
              ],
            ),
          );
        },
      );

  IconData _mealIcon(MealType t) => switch (t) {
        MealType.breakfast => Icons.free_breakfast,
        MealType.lunch => Icons.restaurant,
        MealType.dinner => Icons.dinner_dining,
        MealType.snack => Icons.cookie,
      };
}
