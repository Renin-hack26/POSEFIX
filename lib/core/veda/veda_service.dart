import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/chat_message.dart';
import '../../domain/repositories/session_repository.dart';
import '../../domain/repositories/veda_repository.dart';
import '../../domain/repositories/workout_repository.dart';
import '../di/app_dependencies.dart';
import '../errors/app_exception.dart';

/// VEDA service — the chat screen's single entry point to the assistant.
///
/// GROQ-first: every send is a live [VedaRepository.complete] call (model
/// `openai/gpt-oss-120b`; the API key is injected at build time via
/// `--dart-define=GROQ_API_KEY` — never hardcoded, never read at runtime).
/// The user's last five sessions feed the system prompt as context.
///
/// Failures surface as typed [AppException]s — the chat never fakes a reply:
/// - API key missing → [VedaUnavailableException] ("API key not configured
///   for this build") from the repository.
/// - Offline / socket / HTTP failure → [VedaUnavailableException]
///   ("VEDA needs a connection …").
class VedaService {
  VedaService(this._veda, this._sessions, this._workouts);

  final VedaRepository _veda;
  final SessionRepository _sessions;
  final WorkoutRepository _workouts;

  /// Turns sent to GROQ (system prompt + the last [_historyTurns] turns).
  static const int _historyTurns = 12;

  /// Restored conversation, oldest first (shown on open).
  Future<List<ChatMessage>> history() => _veda.history();

  /// Send [prompt] and return the persisted assistant [ChatMessage].
  Future<ChatMessage> sendMessage(String prompt) async {
    final userMessage = ChatMessage(
      id: _newId(),
      role: ChatRole.user,
      text: prompt,
      createdAt: DateTime.now(),
    );
    final allTurns = [...await _veda.history(), userMessage];
    final turns = allTurns.length > _historyTurns
        ? allTurns.sublist(allTurns.length - _historyTurns)
        : allTurns;

    final reply = await _complete(turns);

    final assistantMessage = ChatMessage(
      id: _newId(),
      role: ChatRole.assistant,
      text: reply,
      createdAt: DateTime.now(),
    );
    await _veda.saveMessage(userMessage);
    await _veda.saveMessage(assistantMessage);
    return assistantMessage;
  }

  /// One live GROQ completion; failures map to honest messages.
  Future<String> _complete(List<ChatMessage> turns) async {
    try {
      return await _veda.complete(
        turns: turns,
        systemPrompt: await _systemPrompt(),
      );
    } on VedaUnavailableException {
      rethrow; // already precise (missing key / unreachable)
    } on AppException {
      // Socket errors and timeouts land here ([NetworkException]).
      throw const VedaUnavailableException(
          'VEDA needs a connection — check your internet and try again');
    }
  }

  /// Fitness-coach system prompt, grounded in the user's last five sessions
  /// (name / date / reps / form accuracy) with a kind medical boundary.
  Future<String> _systemPrompt() async {
    final recent = await _sessions.history(limit: 5);
    final buffer = StringBuffer('''
You are VEDA, the in-app fitness coach of FixPose, an on-device pose detection workout app. Be concise and form-safety-focused.
- Plain text answers, no markdown, no emojis.
- Give exercise, nutrition and recovery guidance only. Never diagnose or treat medical conditions; if asked about pain, injury or a diagnosis, kindly say you are not a medical professional and suggest seeing a qualified clinician.
- Use only the real data below; never invent workouts the user does not have.

Recent sessions (newest first):''');
    if (recent.isEmpty) {
      buffer.write('\n- none yet');
    } else {
      for (final session in recent) {
        final workout = await _workouts.byId(session.workoutId);
        final name = workout?.name ?? session.workoutId;
        buffer.write(
          '\n- $name, ${_formatDate(session.startedAt)} — '
          '${session.totalReps} reps, ${session.formAccuracyPct.round()}% form',
        );
      }
    }
    return buffer.toString();
  }

  String _formatDate(DateTime dt) => '${dt.month}/${dt.day}/${dt.year}';

  String _newId() => DateTime.now().microsecondsSinceEpoch.toString();
}

/// Chat-UI service provider (repository + context sources from the DI graph).
final vedaServiceProvider = Provider<VedaService>((ref) {
  return VedaService(
    ref.watch(vedaRepositoryProvider),
    ref.watch(sessionRepositoryProvider),
    ref.watch(workoutRepositoryProvider),
  );
});
