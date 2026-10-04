import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/sync/server_payload.dart';
import 'app_database.dart';
import 'hive_service.dart';

/// Periodic account sync — PLANNING §2 / §4 SYNC_ENGINE.
///
/// Offline-first contract: local writes never block on the network. The
/// engine (1) **uploads** dirty rows (`syncedAt IS NULL`) on a 15-minute
/// sweep and on sign-in, (2) **downloads + merges** so every device sees the
/// account's history/plans/metrics/meals/strike/chat, (3) **wipes** local
/// account data on sign-out (privacy boundary; bundled content unaffected).
///
/// Conflict policy (LWW approximation): a dirty local row wins; clean rows
/// yield to the server. An edit always clears the watermark, so "edited since
/// last sync" decides the winner. Sessions upload only when completed.
class SyncEngine {
  SyncEngine(this._db, this._supabase);

  final AppDatabase _db;
  final SupabaseClient _supabase;

  static const Duration sweepInterval = Duration(minutes: 15);
  static const Duration _ioTimeout = Duration(seconds: 20);
  static const int _batchSize = 500;

  Timer? _timer;
  StreamSubscription<AuthState>? _authSub;
  bool _running = false;
  bool _started = false;

  /// Last successful sync — surfaced in Settings (persisted in Hive).
  final ValueNotifier<DateTime?> lastSyncedAt = ValueNotifier<DateTime?>(null);

  void start() {
    if (_started) return;
    _started = true;

    final ms = HiveService.getInt(HiveService.kLastSyncedAt);
    if (ms != null) {
      lastSyncedAt.value = DateTime.fromMillisecondsSinceEpoch(ms);
    }

    _authSub = _supabase.auth.onAuthStateChange.listen((state) {
      switch (state.event) {
        case AuthChangeEvent.signedIn:
          unawaited(syncNow()); // fresh device → pull everything
        case AuthChangeEvent.signedOut:
          unawaited(wipeLocal());
        default:
          break;
      }
    });

    _timer = Timer.periodic(sweepInterval, (_) => syncNow());
    unawaited(syncNow());
  }

  void dispose() {
    _timer?.cancel();
    _authSub?.cancel();
  }

  /// One upload+download pass. Re-entrant calls are dropped while running.
  Future<void> syncNow() async {
    if (_running) return;
    final user = _supabase.auth.currentUser;
    if (user == null) return;
    _running = true;
    try {
      await _upload(user.id);
      await _download(user.id);
      final now = DateTime.now();
      lastSyncedAt.value = now;
      await HiveService.setInt(
          HiveService.kLastSyncedAt, now.millisecondsSinceEpoch);
    } catch (e) {
      // Offline / server hiccups are normal — data stays dirty and retries.
      debugPrint('sync: pass skipped (${e.runtimeType})');
    } finally {
      _running = false;
    }
  }

  /// Sign-out privacy boundary (also used by account deletion).
  Future<void> wipeLocal() async {
    await _db.wipeUserTables();
    lastSyncedAt.value = null;
    await HiveService.remove(HiveService.kLastSyncedAt);
  }

  // --- upload -------------------------------------------------------------

  Future<void> _upload(String uid) async {
    final now = DateTime.now();

    final sessions = await _db.sessionDao.dirty();
    await _upsertAll(
        'workout_sessions', sessions.map((s) => sessionToServer(s, uid)));
    for (final s in sessions) {
      await _db.sessionDao.markSynced(s.id, now);
    }

    final plan = await _db.planDao.dirty();
    if (plan != null) {
      await _upsertAll('training_plans', [planToServer(plan, uid)]);
      await _db.planDao.markSynced(plan.id, now);
    }

    final entries = await _db.nutritionDao.dirtyEntries();
    await _upsertAll(
        'meal_entries', entries.map((e) => mealEntryToServer(e, uid)));
    for (final e in entries) {
      await _db.nutritionDao.markEntrySynced(e.id, now);
    }

    final target = await _db.nutritionDao.target();
    if (target != null && target.syncedAt == null) {
      await _upsertAll('meal_targets', [mealTargetToServer(target, uid)]);
      await _db.nutritionDao.markTargetSynced(now);
    }

    final metrics = await _db.progressDao.dirtyMetrics();
    await _upsertAll(
        'body_metrics', metrics.map((m) => metricToServer(m, uid)));
    for (final m in metrics) {
      await _db.progressDao.markMetricSynced(m.dateKey, now);
    }

    final strike = await _db.progressDao.dirtyStrike();
    if (strike != null) {
      await _upsertAll('strike_states', [strikeToServer(strike, uid)]);
      await _db.progressDao.markStrikeSynced(now);
    }

    final chat = await _db.chatDao.dirty();
    await _upsertAll('chat_messages', chat.map((m) => chatToServer(m, uid)));
    for (final m in chat) {
      await _db.chatDao.markSynced(m.id, now);
    }
  }

  Future<void> _upsertAll(
    String table,
    Iterable<Map<String, dynamic>> rows,
  ) async {
    final all = rows.toList(growable: false);
    // No dirty rows → no POST. An empty upsert is wasted network at best
    // and a backend rejection that wedges the whole pass at worst.
    if (all.isEmpty) return;
    for (var i = 0; i < all.length; i += _batchSize) {
      final chunk = all.sublist(i, min(i + _batchSize, all.length));
      await _supabase.from(table).upsert(chunk).timeout(_ioTimeout);
    }
  }

  // --- download + merge ---------------------------------------------------

  Future<void> _download(String uid) async {
    // Completed/abandoned sessions: append-only → insert when missing.
    // Every row merges independently: one poison server row skips loudly
    // instead of aborting the pass and wedging every later sweep on it.
    for (final r in await _select('workout_sessions', uid)) {
      try {
        final server = sessionFromServer(r);
        final local = await _db.sessionDao.byId(server.id);
        if (local == null || local.syncedAt != null) {
          await _db.sessionDao.upsert(server);
        }
      } catch (e) {
        debugPrint('sync: skipping unreadable workout_sessions row ($e)');
      }
    }

    for (final r in await _select('training_plans', uid)) {
      try {
        final server = planFromServer(r);
        final local = await _db.planDao.byId(server.id);
        if (local == null || local.syncedAt != null) {
          await _db.planDao.upsert(server);
        }
      } catch (e) {
        debugPrint('sync: skipping unreadable training_plans row ($e)');
      }
    }

    for (final r in await _select('meal_entries', uid)) {
      try {
        var server = mealEntryFromServer(r);
        final local = await _db.nutritionDao.entryById(server.id);
        // The meal clock time is device-local (never uploaded) — keep the
        // local value when the mirror row lands.
        if (local != null &&
            local.timeMillis != null &&
            server.timeMillis == null) {
          server = server.copyWith(timeMillis: local.timeMillis);
        }
        if (local == null || local.syncedAt != null) {
          await _db.nutritionDao.upsertEntry(server);
        }
      } catch (e) {
        debugPrint('sync: skipping unreadable meal_entries row ($e)');
      }
    }

    final targets = await _select('meal_targets', uid);
    if (targets.isNotEmpty) {
      try {
        final server = mealTargetFromServer(targets.first);
        final local = await _db.nutritionDao.target();
        if (local == null || local.syncedAt != null) {
          await _db.nutritionDao.saveTarget(server);
        }
      } catch (e) {
        debugPrint('sync: skipping unreadable meal_targets row ($e)');
      }
    }

    for (final r in await _select('body_metrics', uid)) {
      try {
        final server = metricFromServer(r);
        final local = await _db.progressDao.metricById(server.dateKey);
        if (local == null || local.syncedAt != null) {
          await _db.progressDao.upsertMetric(server);
        }
      } catch (e) {
        debugPrint('sync: skipping unreadable body_metrics row ($e)');
      }
    }

    final strikes = await _select('strike_states', uid);
    if (strikes.isNotEmpty) {
      try {
        final server = strikeFromServer(strikes.first);
        final local = await _db.progressDao.strike();
        if (local == null || local.syncedAt != null) {
          await _db.progressDao.saveStrike(server);
        }
      } catch (e) {
        debugPrint('sync: skipping unreadable strike_states row ($e)');
      }
    }

    for (final r in await _select('chat_messages', uid)) {
      try {
        final server = chatFromServer(r);
        final local = await _db.chatDao.byId(server.id);
        if (local == null || local.syncedAt != null) {
          await _db.chatDao.upsert(server);
        }
      } catch (e) {
        debugPrint('sync: skipping unreadable chat_messages row ($e)');
      }
    }
  }

  Future<List<Map<String, dynamic>>> _select(
      String table, String uid) async {
    // Scope every pull to the signed-in account: without the filter a
    // multi-user backend (or missing RLS) leaks other users' rows into
    // this device's tables — and `targets.first`/`strikes.first` would
    // let an arbitrary stranger's row overwrite ours.
    final rows = await _supabase
        .from(table)
        .select()
        .eq('user_id', uid)
        .timeout(_ioTimeout);
    return [
      for (final r in rows) Map<String, dynamic>.from(r as Map),
    ];
  }
}
