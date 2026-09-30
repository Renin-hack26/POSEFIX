import '../../core/utils/extensions.dart';
import '../../core/utils/id_gen.dart';
import '../entities/chat_message.dart';
import '../repositories/plan_repository.dart';
import '../repositories/progress_repository.dart';
import '../repositories/session_repository.dart';
import '../repositories/veda_repository.dart';
import '../repositories/workout_repository.dart';

/// Ask VEDA (PLANNING section 5.6) - GROQ when online; **local retrieval
/// fallback** answers from the account's own data when the network fails, so
/// the chat is never a dead end.
class AskVeda {
  AskVeda(
    this._veda,
    this._sessions,
    this._plan,
    this._progress,
    this._workouts,
  );

  final VedaRepository _veda;
  final SessionRepository _sessions;
  final PlanRepository _plan;
  final ProgressRepository _progress;
  final WorkoutRepository _workouts;

  static const int _historyTurns = 12;

  /// Returns the assistant message (already persisted, with the user turn).
  Future<ChatMessage> call(String prompt) async {
    final now = DateTime.now();
    final history = await _veda.history();
    final userMessage = ChatMessage(
      id: newId(),
      role: ChatRole.user,
      text: prompt,
      createdAt: now,
    );

    final context = await _buildContext(now);
    String reply;
    try {
      final turns = [...history, userMessage];
      reply = await _veda.complete(
        turns: turns.length > _historyTurns
            ? turns.sublist(turns.length - _historyTurns)
            : turns,
        systemPrompt: _systemPrompt(context),
      );
    } catch (_) {
      // Offline / error -> local retrieval over the user's data.
      reply = _localReply(context);
    }

    final assistantMessage = ChatMessage(
      id: newId(),
      role: ChatRole.assistant,
      text: reply,
      createdAt: DateTime.now(),
    );
    await _veda.saveMessage(userMessage);
    await _veda.saveMessage(assistantMessage);
    return assistantMessage;
  }

  // --- context -----------------------------------------------------------

  Future<_VedaContext> _buildContext(DateTime now) async {
    final strike = await _progress.strike();
    final from = now.startOfWeek;
    final week = await _sessions.sessionsBetween(from, now);
    final history = await _sessions.history(limit: 1);
    final last = history.isEmpty ? null : history.first;
    final plan = await _plan.currentPlan();
    final today = plan?.sessionsFor(now) ?? const [];
    final todayNames = <String>[];
    for (final ps in today) {
      final w = await _workouts.byId(ps.workoutId);
      if (w != null) todayNames.add(w.name);
    }
    return _VedaContext(
      strike: strike?.currentStrike ?? 0,
      weekSessions: week.length,
      weekMinutes: week.fold<int>(0, (s, x) => s + x.durationSec) ~/ 60,
      weekReps: week.fold<int>(0, (s, x) => s + x.totalReps),
      lastSessionName:
          last == null ? null : (await _workouts.byId(last.workoutId))?.name,
      lastSessionGapDays: strike?.lastActiveDateKey.isEmpty ?? true
          ? null
          : now.startOfDay
              .difference(DateTime.parse(strike!.lastActiveDateKey))
              .inDays,
      todayWorkouts: todayNames,
      hasPlan: plan != null,
    );
  }

  String _systemPrompt(_VedaContext c) => '''
You are VEDA, the in-app fitness coach of FixPose, an on-device pose detection workout app. Answer as a supportive, precise personal coach. Rules:
- Max 80 words per answer; plain text, no markdown, no emojis.
- Only give exercise, nutrition and recovery guidance; never medical advice; if asked about pain/injury, advise seeing a professional.
- Use the user's real data below when relevant; never invent workouts they do not have.

User data:
- Consistency strike: ${c.strike} day(s)
- This week: ${c.weekSessions} session(s), ${c.weekMinutes} min, ${c.weekReps} reps
- Last workout: ${c.lastSessionName ?? 'none yet'}${c.lastSessionGapDays == null ? '' : ' (${c.lastSessionGapDays} day(s) ago)'}
- Today's plan: ${c.todayWorkouts.isEmpty ? (c.hasPlan ? 'rest day' : 'no plan generated yet') : c.todayWorkouts.join(', ')}''';

  /// Data-grounded offline answer (local retrieval).
  String _localReply(_VedaContext c) {
    final buffer = StringBuffer(
        "I'm offline right now, so I can't think straight - but here's what I know from your data: ");
    if (c.weekSessions == 0 && c.lastSessionName == null) {
      buffer.write(
          'you haven\'t completed a session yet. Generate your plan in the Plan tab and start with a short one - I\'ll be back online soon.');
      return buffer.toString();
    }
    buffer.write(
        'this week you trained ${c.weekSessions} time(s) for ${c.weekMinutes} min and ${c.weekReps} reps, with a ${c.strike}-day strike');
    if (c.lastSessionName != null) {
      buffer.write(', last workout was ${c.lastSessionName}');
    }
    if (c.todayWorkouts.isNotEmpty) {
      buffer.write('. Today you have ${c.todayWorkouts.join(', ')} - solid, stick to it!');
    } else {
      buffer.write('. No session today - a short walk or mobility flow keeps the streak honest.');
    }
    return buffer.toString();
  }
}

class _VedaContext {
  const _VedaContext({
    required this.strike,
    required this.weekSessions,
    required this.weekMinutes,
    required this.weekReps,
    required this.lastSessionName,
    required this.lastSessionGapDays,
    required this.todayWorkouts,
    required this.hasPlan,
  });

  final int strike;
  final int weekSessions;
  final int weekMinutes;
  final int weekReps;
  final String? lastSessionName;
  final int? lastSessionGapDays;
  final List<String> todayWorkouts;
  final bool hasPlan;
}
