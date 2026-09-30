/// Unit tests for session-audio glue — pure logic only, no platform channels.
library;

import 'package:fixpose/core/audio/sound_engine.dart';
import 'package:fixpose/core/pose/brain_engine.dart';
import 'package:fixpose/core/pose/pose_analyzer.dart';
import 'package:fixpose/engines/session_audio/session_audio_cues.dart';
import 'package:flutter_test/flutter_test.dart';

/// Fake engine that records calls without touching platform channels.
class FakeSoundEngine extends SoundEngine {
  final List<Sfx> played = <Sfx>[];
  final List<String> cues = <String>[];
  final List<String> urgent = <String>[];
  final List<SessionMood> completions = <SessionMood>[];

  @override
  Future<void> play(Sfx sfx, {double? volume}) async {
    played.add(sfx);
  }

  @override
  Future<bool> speakCue(String cue) async {
    cues.add(cue);
    return true;
  }

  @override
  Future<void> speakUrgent(String cue) async {
    urgent.add(cue);
  }

  @override
  Future<void> completeSession(SessionMood mood) async {
    completions.add(mood);
  }
}

FeedbackMessage msg(String audioCue, String severity) => FeedbackMessage(
      name: 'rule',
      message: audioCue,
      audioCue: audioCue,
      severity: severity,
    );

void main() {
  group('computeMood', () {
    test('triumphant on high completion + good form', () {
      expect(
        computeMood(
          targetCompletion: 1.0,
          avgForm: 90,
          exitedEarly: false,
        ),
        SessionMood.triumphant,
      );
    });

    test('energetic on high completion + low form', () {
      expect(
        computeMood(
          targetCompletion: 0.95,
          avgForm: 70,
          exitedEarly: false,
        ),
        SessionMood.energetic,
      );
    });

    test('encouraging on low completion', () {
      expect(
        computeMood(
          targetCompletion: 0.5,
          avgForm: 90,
          exitedEarly: false,
        ),
        SessionMood.encouraging,
      );
    });

    test('gentle when exited early', () {
      expect(
        computeMood(
          targetCompletion: 1.0,
          avgForm: 95,
          exitedEarly: true,
        ),
        SessionMood.gentle,
      );
    });

    test('boundaries: 0.9 / 80 is triumphant', () {
      expect(
        computeMood(
          targetCompletion: 0.9,
          avgForm: 80,
          exitedEarly: false,
        ),
        SessionMood.triumphant,
      );
      expect(
        computeMood(
          targetCompletion: 0.9,
          avgForm: 79.9,
          exitedEarly: false,
        ),
        SessionMood.energetic,
      );
      expect(
        computeMood(
          targetCompletion: 0.899,
          avgForm: 95,
          exitedEarly: false,
        ),
        SessionMood.encouraging,
      );
    });
  });

  group('warningCueFor', () {
    test('picks first warning audio cue', () {
      final List<FeedbackMessage> feedback = <FeedbackMessage>[
        msg('Nice pace', 'info'),
        msg('Go deeper!', 'warning'),
        msg('Keep chest up!', 'warning'),
      ];
      expect(warningCueFor(feedback), 'Go deeper!');
    });

    test('picks error cues too', () {
      final List<FeedbackMessage> feedback = <FeedbackMessage>[
        msg('Stop now', 'error'),
      ];
      expect(warningCueFor(feedback), 'Stop now');
    });

    test('ignores info-only feedback', () {
      final List<FeedbackMessage> feedback = <FeedbackMessage>[
        msg('Good form', 'info'),
      ];
      expect(warningCueFor(feedback), isNull);
    });

    test('empty feedback returns null', () {
      expect(warningCueFor(<FeedbackMessage>[]), isNull);
    });
  });

  group('framing-change dedup', () {
    test('same cue spoken once until it changes', () async {
      final FakeSoundEngine engine = FakeSoundEngine();
      final SessionAudioCues cues = SessionAudioCues(engine);

      await cues.onFraming(FramingCue.stepBack);
      expect(engine.urgent, <String>[framingCueLine(FramingCue.stepBack)]);
      expect(cues.lastFraming, FramingCue.stepBack);

      await cues.onFraming(FramingCue.stepBack);
      expect(engine.urgent.length, 1);

      await cues.onFraming(FramingCue.moveLeft);
      expect(engine.urgent.length, 2);
      expect(engine.urgent.last, framingCueLine(FramingCue.moveLeft));
    });

    test('ok never speaks but resets the latch', () async {
      final FakeSoundEngine engine = FakeSoundEngine();
      final SessionAudioCues cues = SessionAudioCues(engine);

      await cues.onFraming(FramingCue.ok);
      expect(engine.urgent, isEmpty);

      await cues.onFraming(FramingCue.stepBack);
      await cues.onFraming(FramingCue.ok);
      expect(engine.urgent.length, 1);

      await cues.onFraming(FramingCue.stepBack);
      expect(engine.urgent.length, 2);
    });
  });

  group('warning cooldown', () {
    test('same cue suppressed within cooldown', () async {
      final FakeSoundEngine engine = FakeSoundEngine();
      final SessionAudioCues cues = SessionAudioCues(engine);

      await cues.onWarning('Go deeper!');
      await cues.onWarning('Go deeper!');
      expect(engine.cues.length, 1);
      expect(engine.played.where((Sfx s) => s == Sfx.warning).length, 1);
    });

    test('different cues both speak', () async {
      final FakeSoundEngine engine = FakeSoundEngine();
      final SessionAudioCues cues = SessionAudioCues(engine);

      await cues.onWarning('Go deeper!');
      await cues.onWarning('Chest up!');
      expect(engine.cues.length, 2);
    });
  });
}
