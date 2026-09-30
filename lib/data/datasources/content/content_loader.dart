import 'dart:convert';

import 'package:flutter/services.dart' show AssetBundle, rootBundle;

import '../../../core/errors/app_exception.dart';
import '../../../domain/entities/exercise.dart';
import '../../../domain/entities/meal.dart';
import '../../../domain/entities/plan_template.dart';
import '../../../domain/entities/workout.dart';
import '../../mappers/content_mappers.dart';

/// Loads bundled seed content from `assets/data/*.json` exactly once and
/// caches it in memory (parse errors surface as [StorageException]).
class ContentLoader {
  ContentLoader({AssetBundle? bundle}) : _bundle = bundle ?? rootBundle;

  final AssetBundle _bundle;

  List<Exercise>? _exercises;
  List<Workout>? _workouts;
  List<FoodItem>? _foods;
  List<String>? _tips;
  List<PlanTemplate>? _templates;

  Future<List<dynamic>> _read(String asset) async {
    try {
      final raw = await _bundle.loadString(asset);
      final parsed = jsonDecode(raw);
      if (parsed is! List && parsed is! Map) {
        throw const FormatException('unexpected root type');
      }
      return parsed is List ? parsed : <dynamic>[parsed];
    } catch (_) {
      throw StorageException('Bundled content failed to load ($asset)');
    }
  }

  Future<List<Exercise>> exercises() async => _exercises ??= (await _read(
          'assets/data/exercises.json'))
      .map((e) => exerciseFromJson(e as Map<String, dynamic>,
          'exercises.json'))
      .toList(growable: false);

  Future<List<Workout>> workouts() async => _workouts ??= (await _read(
          'assets/data/workouts.json'))
      .map((e) =>
          workoutFromJson(e as Map<String, dynamic>, 'workouts.json'))
      .toList(growable: false);

  Future<List<FoodItem>> foods() async => _foods ??= (await _read(
          'assets/data/foods.json'))
      .map((e) => foodFromJson(e as Map<String, dynamic>, 'foods.json'))
      .toList(growable: false);

  Future<List<String>> tips() async => _tips ??= (await _read(
          'assets/data/tips.json'))
      .map((e) => (e as Map<String, dynamic>)['text'] as String)
      .toList(growable: false);

  Future<List<PlanTemplate>> planTemplates() async {
    final cached = _templates;
    if (cached != null) return cached;
    // NOTE: `.first['templates']` is `dynamic`, so `.map()` on it dispatches
    // dynamically and `.toList()` yields `List<dynamic>` — the old
    // `as List<PlanTemplate>` cast threw a TypeError on EVERY call, which is
    // exactly what broke onboarding plan generation on device. Cast to
    // `List<dynamic>` first so `.map()` is statically typed.
    try {
      final root = await _read('assets/data/plan_templates.json');
      final raw =
          (root.first as Map<String, dynamic>)['templates'] as List<dynamic>;
      final parsed = raw
          .map((t) => planTemplateFromJson(
              t as Map<String, dynamic>, 'plan_templates.json'))
          .toList(growable: false);
      return _templates = parsed;
    } catch (_) {
      throw StorageException(
          'Bundled content failed to load (plan_templates.json)');
    }
  }
}
