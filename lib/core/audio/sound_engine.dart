/// FixPose Sound Engine — spoken coaching cues (TTS) + synthesized SFX.
///
/// Latency budget (PLANNING §4.3): first cue < 0.5 s after detection.
/// TTS is pre-warmed at startup; SFX are synthesized WAVs played through
/// Android SoundPool (~20-50 ms) via the `fixpose/sfx` channel — no audio
/// plugin dependency, fully offline, zero spend.
///
/// Speech arbiter (v1.1.11 user feedback): cues never overlap and never
/// stack a backlog — one line holds the floor at a time, a newer cue
/// replaces the waiting one, a breath gap separates lines, only urgent
/// (safety) lines interrupt, and a watchdog frees the floor when the
/// platform never answers.
///
/// Same-cue repeats are rate-limited (2 s cooldown); urgent cues
/// ("Step back!") bypass the cooldown.
library;

import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:path_provider/path_provider.dart';

import 'tone_synth.dart';

/// Sound effect types for distinct workout events.
enum Sfx {
  /// Clean rep completed.
  rep,

  /// Full set finished.
  set,

  /// Session finished — all targets hit, great form.
  sessionTriumphant,

  /// Session finished — completed but struggled.
  sessionEncouraging,

  /// Session finished early / partial — gentle, no judgment.
  sessionGentle,

  /// High-intensity session finished — energetic.
  sessionEnergetic,

  /// Form warning (knee cave, hip sag, shallow depth).
  warning,

  /// Transition to the next exercise.
  transition,

  /// Rest period started.
  restStart,

  /// Rest over — back to work.
  restEnd,

  /// Major milestone (PR, streak record).
  celebration,
}

/// Mood-based session completion (user requirement: different sounds for
/// different purposes, matching the mood of the reason).
enum SessionMood {
  /// All targets hit with good form.
  triumphant,

  /// Finished but struggled / targets partially missed.
  encouraging,

  /// Exited early — gentle, encouraging, never judgmental.
  gentle,

  /// High-intensity session completed.
  energetic,
}

/// Spoken line paired with each completion mood.
String completionLine(SessionMood mood) => switch (mood) {
      SessionMood.triumphant => 'Workout complete. Outstanding work today.',
      SessionMood.encouraging =>
        'Workout complete. You showed up and finished — that counts.',
      SessionMood.gentle =>
        'Session saved. Every bit of movement matters — see you next time.',
      SessionMood.energetic =>
        'Workout complete. High intensity, well earned. Recover well.',
    };

class SoundEngine {
  SoundEngine();

  static const _channel = MethodChannel('fixpose/sfx');
  static const _cueCooldown = Duration(seconds: 2);

  /// Slower, clearer delivery (user feedback) — applied at init.
  static const double speechRate = 0.45;

  /// Breath gap between consecutive lines: the next cue waits this long
  /// after the previous line completes.
  static const _breathGap = Duration(milliseconds: 250);

  FlutterTts? _tts;
  bool _ttsReady = false;
  String? _lastCue;
  DateTime? _lastCueAt;

  /// True while a spoken line holds the floor (on the platform TTS).
  bool _isSpeaking = false;

  /// Newest cue that arrived while the floor was busy — replaces any older
  /// waiter, so a backlog can never stack up.
  String? _queuedLine;

  /// Defensive recovery when the platform never signals completion.
  Timer? _watchdog;

  /// Breath-gap delay for the queued line after a completion.
  Timer? _breathGapTimer;

  final Map<Sfx, String> _sfxPaths = {};
  bool _sfxReady = false;
  bool _initializing = false;

  bool _muted = false;
  double _masterVolume = 1.0;
  double _ttsVolume = 1.0;
  double _sfxVolume = 1.0;

  bool get isMuted => _muted;
  double get masterVolume => _masterVolume;

  /// True while a spoken line holds the floor.
  bool get isSpeaking => _isSpeaking;

  /// The cue waiting for the floor, if any (newest waiter wins).
  String? get queuedLine => _queuedLine;

  /// Warms TTS + synthesizes SFX files. Safe to call twice; never throws —
  /// audio must never break app boot.
  Future<void> initialize() async {
    if (_sfxReady && _ttsReady) return;
    if (_initializing) return;
    _initializing = true;
    try {
      await _initTts();
    } catch (_) {
      _ttsReady = false;
    }
    try {
      await _initSfx();
    } catch (_) {
      _sfxReady = false;
    }
    _initializing = false;
  }

  Future<void> _initTts() async {
    final tts = FlutterTts();
    await tts.setLanguage('en-US');
    await tts.setSpeechRate(speechRate);
    await tts.setVolume(1.0);
    await tts.setPitch(1.0);
    await tts.awaitSpeakCompletion(false);
    _tts = tts;
    _ttsReady = true;
    // Pre-warm the engine so the first real cue lands inside 0.5 s.
    try {
      await tts.speak(' ');
      await tts.stop();
    } catch (_) {
      // Pre-warm is best-effort on some engines.
    }
    // Registered AFTER the pre-warm so its utterance can never drive the
    // arbiter floor.
    tts.setCompletionHandler(_onTtsComplete);
  }

  Future<void> _initSfx() async {
    final dir = await getTemporaryDirectory();
    final sfxDir = Directory('${dir.path}/fixpose_sfx');
    if (!await sfxDir.exists()) await sfxDir.create(recursive: true);
    for (final sfx in Sfx.values) {
      final path = '${sfxDir.path}/${sfx.name}.wav';
      final file = File(path);
      if (!await file.exists()) {
        await file.writeAsBytes(_buildWav(sfx), flush: true);
      }
      _sfxPaths[sfx] = path;
    }
    _sfxReady = true;
  }

  /// Speak a coaching cue through the arbiter: rate-limited per identical
  /// cue (2 s). Returns true when accepted — spoken immediately, or queued
  /// when another line holds the floor (the newest waiter replaces any
  /// older one, so back-to-back cues never stack).
  Future<bool> speakCue(String cue) async {
    if (_muted) return false;
    if (!_ttsReady) await initialize();
    final tts = _tts;
    if (!_ttsReady || tts == null) return false;
    final now = DateTime.now();
    if (_lastCue == cue &&
        _lastCueAt != null &&
        now.difference(_lastCueAt!) < _cueCooldown) {
      return false;
    }
    _lastCue = cue;
    _lastCueAt = now;
    if (_isSpeaking || _breathGapTimer != null) {
      _queuedLine = cue;
      return true;
    }
    return _speakNow(tts, cue);
  }

  /// Speak immediately, bypassing the cooldown AND the queue (safety /
  /// framing cues): cuts the current line and drops the waiter.
  Future<void> speakUrgent(String cue) async {
    if (_muted) return;
    if (!_ttsReady) await initialize();
    final tts = _tts;
    if (!_ttsReady || tts == null) return;
    _lastCue = cue;
    _lastCueAt = DateTime.now();
    _breathGapTimer?.cancel();
    _breathGapTimer = null;
    // The stale waiter is irrelevant once safety speaks.
    _queuedLine = null;
    try {
      if (_isSpeaking) {
        await tts.stop();
      }
    } catch (_) {
      // Cutting the line is best-effort.
    }
    _releaseFloor();
    await _speakNow(tts, cue);
  }

  /// Puts [cue] on the platform TTS and holds the floor until completion,
  /// error or watchdog. Never throws — audio must never break the workout.
  Future<bool> _speakNow(FlutterTts tts, String cue) async {
    try {
      _isSpeaking = true;
      _armWatchdog(cue);
      await tts.setVolume((_ttsVolume * _masterVolume).clamp(0.0, 1.0));
      await tts.speak(cue);
      return true;
    } catch (_) {
      _releaseFloor();
      return false;
    }
  }

  /// Platform signalled the end of the current line: free the floor, then
  /// hand it to the waiter after the breath gap.
  void _onTtsComplete() {
    if (!_isSpeaking) return; // stale completion — ignore
    _releaseFloor();
    final next = _queuedLine;
    _queuedLine = null;
    if (next == null || _muted) return;
    _breathGapTimer?.cancel();
    _breathGapTimer = Timer(_breathGap, () {
      _breathGapTimer = null;
      if (_muted || _isSpeaking) return;
      final tts = _tts;
      if (!_ttsReady || tts == null) return;
      // A cue that arrived during the gap wins over the older waiter.
      final line = _queuedLine ?? next;
      _queuedLine = null;
      unawaited(_speakNow(tts, line));
    });
  }

  /// Frees the floor when the platform never answers: ~1.7 s for a 1-char
  /// line, scaling with length so long lines are not cut short.
  void _armWatchdog(String cue) {
    _watchdog?.cancel();
    _watchdog = Timer(
      Duration(milliseconds: 1500 + cue.length * 30),
      () {
        _watchdog = null;
        if (!_isSpeaking) return;
        _isSpeaking = false;
        stopTts(); // free a wedged platform engine
      },
    );
  }

  void _releaseFloor() {
    _isSpeaking = false;
    _watchdog?.cancel();
    _watchdog = null;
  }

  Future<void> stopTts() async {
    try {
      await _tts?.stop();
    } catch (_) {
      // Best effort.
    }
  }

  /// Play a synthesized effect. No-op (never throws) when the host channel
  /// is unavailable — e.g. widget tests — or when muted.
  Future<void> play(Sfx sfx, {double? volume}) async {
    if (_muted) return;
    if (!_sfxReady) await initialize();
    final path = _sfxPaths[sfx];
    if (!_sfxReady || path == null) return;
    final v = ((volume ?? _sfxVolume) * _masterVolume).clamp(0.0, 1.0);
    try {
      await _channel.invokeMethod<void>('play', {'path': path, 'volume': v});
    } on MissingPluginException catch (_) {
      // Test harness / preview — silence is correct.
    } catch (_) {
      // Audio must never crash a session.
    }
  }

  /// Session-complete fanfare: mood-matched sound + spoken line.
  Future<void> completeSession(SessionMood mood) async {
    final sfx = switch (mood) {
      SessionMood.triumphant => Sfx.sessionTriumphant,
      SessionMood.encouraging => Sfx.sessionEncouraging,
      SessionMood.gentle => Sfx.sessionGentle,
      SessionMood.energetic => Sfx.sessionEnergetic,
    };
    await play(sfx);
    await speakUrgent(completionLine(mood));
  }

  void setMuted(bool muted) {
    _muted = muted;
    if (muted) {
      // Muting mid-sentence cuts the line and drops the waiter — silence
      // means silence. Applies synchronously (the platform stop is async).
      _breathGapTimer?.cancel();
      _breathGapTimer = null;
      _queuedLine = null;
      _releaseFloor();
      stopTts();
    }
  }
  void setMasterVolume(double v) => _masterVolume = v.clamp(0.0, 1.0);
  void setTtsVolume(double v) => _ttsVolume = v.clamp(0.0, 1.0);
  void setSfxVolume(double v) => _sfxVolume = v.clamp(0.0, 1.0);

  Future<void> dispose() async {
    _breathGapTimer?.cancel();
    _breathGapTimer = null;
    _queuedLine = null;
    _releaseFloor();
    await stopTts();
    _ttsReady = false;
    _sfxReady = false;
  }

  // -- synthesis recipes -----------------------------------------------------

  static Uint8List _buildWav(Sfx sfx) {
    switch (sfx) {
      case Sfx.rep:
        return ToneSynth.beep(freqHz: 880, ms: 90);
      case Sfx.set:
        return ToneSynth.sequence(const [
          ToneNote(660, 120),
          ToneNote(880, 160),
        ]);
      case Sfx.sessionTriumphant:
        return ToneSynth.sequence(const [
          ToneNote(523, 140),
          ToneNote(659, 140),
          ToneNote(784, 140),
          ToneNote(1047, 260),
        ]);
      case Sfx.sessionEncouraging:
        return ToneSynth.sequence(const [
          ToneNote(392, 160),
          ToneNote(523, 160),
          ToneNote(659, 240),
        ]);
      case Sfx.sessionGentle:
        return ToneSynth.sequence(
          const [ToneNote(523, 320, volume: 0.6)],
          gapMs: 0,
        );
      case Sfx.sessionEnergetic:
        return ToneSynth.sequence(const [
          ToneNote(523, 90),
          ToneNote(659, 90),
          ToneNote(784, 90),
          ToneNote(1047, 90),
          ToneNote(1319, 220),
        ], gapMs: 25);
      case Sfx.warning:
        return ToneSynth.beep(freqHz: 220, ms: 200, volume: 0.7);
      case Sfx.transition:
        return ToneSynth.sequence(const [
          ToneNote(440, 110),
          ToneNote(660, 140),
        ]);
      case Sfx.restStart:
        return ToneSynth.beep(freqHz: 330, ms: 180, volume: 0.7);
      case Sfx.restEnd:
        return ToneSynth.sequence(const [
          ToneNote(660, 100),
          ToneNote(880, 160),
        ], gapMs: 30);
      case Sfx.celebration:
        return ToneSynth.sequence(const [
          ToneNote(659, 110),
          ToneNote(784, 110),
          ToneNote(1047, 110),
          ToneNote(784, 110),
          ToneNote(1047, 240),
        ], gapMs: 30);
    }
  }
}
