/// FixPose Sound Engine — spoken coaching cues (TTS) + synthesized SFX.
///
/// Latency budget (PLANNING §4.3): first cue < 0.5 s after detection.
/// TTS is pre-warmed at startup; SFX are synthesized WAVs played through
/// Android SoundPool (~20-50 ms) via the `fixpose/sfx` channel — no audio
/// plugin dependency, fully offline, zero spend.
///
/// Same-cue repeats are rate-limited (2 s cooldown); urgent cues
/// ("Step back!") bypass the cooldown.
library;

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

  FlutterTts? _tts;
  bool _ttsReady = false;
  String? _lastCue;
  DateTime? _lastCueAt;

  final Map<Sfx, String> _sfxPaths = {};
  bool _sfxReady = false;
  bool _initializing = false;

  bool _muted = false;
  double _masterVolume = 1.0;
  double _ttsVolume = 1.0;
  double _sfxVolume = 1.0;

  bool get isMuted => _muted;
  double get masterVolume => _masterVolume;

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
    await tts.setSpeechRate(0.52);
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

  /// Speak a coaching cue, rate-limited per identical cue (2 s).
  /// Returns true when actually spoken.
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
    try {
      await tts.setVolume((_ttsVolume * _masterVolume).clamp(0.0, 1.0));
      await tts.speak(cue);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Speak immediately, bypassing the cooldown (safety/framing cues).
  Future<void> speakUrgent(String cue) async {
    if (_muted) return;
    if (!_ttsReady) await initialize();
    final tts = _tts;
    if (!_ttsReady || tts == null) return;
    try {
      await tts.setVolume((_ttsVolume * _masterVolume).clamp(0.0, 1.0));
      await tts.speak(cue);
    } catch (_) {
      // Never let audio break the workout flow.
    }
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

  void setMuted(bool muted) => _muted = muted;
  void setMasterVolume(double v) => _masterVolume = v.clamp(0.0, 1.0);
  void setTtsVolume(double v) => _ttsVolume = v.clamp(0.0, 1.0);
  void setSfxVolume(double v) => _sfxVolume = v.clamp(0.0, 1.0);

  Future<void> dispose() async {
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
