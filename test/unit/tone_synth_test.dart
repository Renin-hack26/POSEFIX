/// Tone synth unit tests — WAV structural validity (header + sizing).
library;

import 'package:fixpose/core/audio/tone_synth.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ToneSynth', () {
    test('beep emits a valid 16-bit mono WAV', () {
      final wav = ToneSynth.beep(freqHz: 880, ms: 100);
      // RIFF....WAVEfmt 
      expect(wav.sublist(0, 4), [0x52, 0x49, 0x46, 0x46]);
      expect(wav.sublist(8, 12), [0x57, 0x41, 0x56, 0x45]);
      // 100 ms @ 22050 Hz = 2205 samples × 2 bytes + 44 header.
      expect(wav.length, 44 + 2205 * 2);
    });

    test('sequence is longer than a single beep', () {
      final single = ToneSynth.beep(freqHz: 660, ms: 100);
      final seq = ToneSynth.sequence(const [
        ToneNote(660, 100),
        ToneNote(880, 100),
      ]);
      expect(seq.length, greaterThan(single.length));
    });

    test('zero-length notes do not crash', () {
      final wav = ToneSynth.beep(freqHz: 440, ms: 0);
      expect(wav.length, greaterThanOrEqualTo(44));
    });
  });
}
