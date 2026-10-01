/// Speech arbiter tests (v1.1.11 user feedback): cues must never overlap,
/// never queue a backlog, respect the breath gap between lines, interrupt
/// only for safety lines, and run at the slower configured pace.
///
/// The real `FlutterTts` instance is driven against a mocked
/// `flutter_tts` channel; completion signals are replayed
/// as platform→Dart calls exactly as Android delivers them.
library;

import 'package:fixpose/core/audio/sound_engine.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const String _ttsChannelName = 'flutter_tts';
const MethodChannel _ttsChannel = MethodChannel(_ttsChannelName);

/// Text of a `speak` call — flutter_tts uses a bare String off-Android
/// (the test host) and a `{text, focus}` map on Android.
String _spokenText(MethodCall call) {
  final Object? args = call.arguments;
  if (args is String) return args;
  return (args as Map)['text'] as String;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late List<MethodCall> calls;

  setUp(() {
    calls = <MethodCall>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_ttsChannel, (MethodCall call) async {
      calls.add(call);
      return null;
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_ttsChannel, null);
  });

  /// Replays a platform→Dart callback on the flutter_tts channel.
  Future<void> fire(String method, {Object? args}) async {
    final ByteData message = const StandardMethodCodec()
        .encodeMethodCall(MethodCall(method, args));
    await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .handlePlatformMessage(_ttsChannelName, message, (_) {});
  }

  List<MethodCall> speaksOf() => calls.where((c) => c.method == 'speak').toList();

  SoundEngine newEngine() => SoundEngine();

  test('speech runs at the slower configured rate', () async {
    final engine = newEngine();
    await engine.initialize();
    final rate =
        calls.firstWhere((c) => c.method == 'setSpeechRate').arguments;
    expect(rate, SoundEngine.speechRate);
    expect(SoundEngine.speechRate, lessThan(0.5),
        reason: 'user asked for slower, clearer delivery');
    await engine.dispose();
  });

  test('back-to-back cues speak one line at a time — newest waiter wins',
      () async {
    final engine = newEngine();
    await engine.initialize();
    calls.clear();

    expect(await engine.speakCue('Line one'), isTrue);
    expect(await engine.speakCue('Line two'), isTrue);
    expect(await engine.speakCue('Line three'), isTrue);
    await pumpEventQueue();

    var speaks = speaksOf();
    expect(speaks, hasLength(1),
        reason: 'second/third cues must wait, not stack');
    expect(_spokenText(speaks.first), 'Line one');
    expect(engine.queuedLine, 'Line three',
        reason: 'latest waiter replaces the stale one');

    await fire('speak.onComplete');
    // The breath gap holds the next line back…
    await Future<void>.delayed(const Duration(milliseconds: 150));
    expect(speaksOf(), hasLength(1), reason: 'no speech during the gap');

    // …then exactly one more line plays (the backlog never catches up).
    await Future<void>.delayed(const Duration(milliseconds: 400));
    speaks = speaksOf();
    expect(speaks, hasLength(2));
    expect(_spokenText(speaks.last), 'Line three');
    expect(engine.queuedLine, isNull);

    await fire('speak.onComplete');
    await Future<void>.delayed(const Duration(milliseconds: 500));
    expect(speaksOf(), hasLength(2), reason: 'nothing left to say');
    await engine.dispose();
  });

  test('urgent line interrupts speech and clears the waiter', () async {
    final engine = newEngine();
    await engine.initialize();
    calls.clear();

    await engine.speakCue('Round two complete');
    await pumpEventQueue();
    expect(speaksOf(), hasLength(1));

    await engine.speakCue('Coach line waiting');
    await engine.speakUrgent('Step back from the screen');
    await pumpEventQueue();

    expect(calls.where((c) => c.method == 'stop'), isNotEmpty,
        reason: 'urgent must cut the current line');
    final speaks = speaksOf();
    expect(_spokenText(speaks.last), 'Step back from the screen');
    expect(engine.queuedLine, isNull,
        reason: 'the stale waiter is irrelevant once safety speaks');

    await fire('speak.onComplete');
    await Future<void>.delayed(const Duration(milliseconds: 500));
    expect(speaksOf(), hasLength(2),
        reason: 'interrupted waiter must never resurface');
    await engine.dispose();
  });

  test('identical cue within the 2 s cooldown is refused', () async {
    final engine = newEngine();
    await engine.initialize();
    calls.clear();

    expect(await engine.speakCue('Knees out'), isTrue);
    await pumpEventQueue();
    expect(await engine.speakCue('Knees out'), isFalse);
    await pumpEventQueue();
    expect(speaksOf(), hasLength(1));
    await engine.dispose();
  });

  test('mute refuses speech and cuts a live line', () async {
    final engine = newEngine();
    await engine.initialize();
    calls.clear();

    await engine.speakCue('Before mute');
    await pumpEventQueue();
    expect(speaksOf(), hasLength(1));

    engine.setMuted(true);
    await pumpEventQueue();
    expect(calls.where((c) => c.method == 'stop'), isNotEmpty,
        reason: 'muting mid-sentence must cut the line');

    expect(await engine.speakCue('After mute'), isFalse);
    await engine.speakUrgent('Urgent while muted');
    await pumpEventQueue();
    expect(speaksOf(), hasLength(1), reason: 'muted engine stays silent');
    await engine.dispose();
  });

  test('watchdog releases the floor when the platform never answers',
      () async {
    final engine = newEngine();
    await engine.initialize();
    calls.clear();

    await engine.speakCue('x');
    await pumpEventQueue();
    expect(engine.isSpeaking, isTrue);

    // No speak.onComplete is ever delivered — only the watchdog can recover.
    await Future<void>.delayed(const Duration(milliseconds: 2300));
    expect(engine.isSpeaking, isFalse,
        reason: 'defensive recovery after ~1.7 s for a 1-char line');

    await engine.speakCue('next cue');
    await pumpEventQueue();
    expect(speaksOf().length, greaterThanOrEqualTo(1),
        reason: 'engine must accept new speech after recovery');
    await engine.dispose();
  });
}
