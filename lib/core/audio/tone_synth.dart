/// FixPose tone synthesizer — pure-Dart WAV generation for sound effects.
///
/// Zero assets, zero downloads, fully offline: every SFX is synthesized as a
/// 16-bit mono WAV at 22050 Hz and cached on disk by [SoundEngine].
/// Short envelopes (8 ms attack, exponential decay) avoid clicks; a soft
/// second harmonic keeps sine tones from sounding harsh on phone speakers.
library;

import 'dart:math' as math;
import 'dart:typed_data';

/// One note in a synthesized sequence.
class ToneNote {
  const ToneNote(this.freqHz, this.ms, {this.volume = 1.0});

  /// Frequency in Hz (e.g. 440 = A4).
  final double freqHz;

  /// Note length in milliseconds (decay tail included).
  final int ms;

  /// Per-note gain 0..1.
  final double volume;
}

class ToneSynth {
  ToneSynth._();

  /// Sample rate — 22050 Hz keeps files small with ample quality for beeps.
  static const int sampleRate = 22050;

  /// Single enveloped tone.
  static Uint8List beep({
    required double freqHz,
    required int ms,
    double volume = 0.8,
  }) =>
      sequence([ToneNote(freqHz, ms, volume: volume)]);

  /// Melody of [notes] separated by [gapMs] of silence.
  static Uint8List sequence(List<ToneNote> notes, {int gapMs = 40}) {
    final gapSamples = (sampleRate * gapMs / 1000).round();
    final parts = <List<double>>[];
    var total = 0;
    for (var i = 0; i < notes.length; i++) {
      final samples = _renderNote(notes[i]);
      parts.add(samples);
      total += samples.length;
      if (i < notes.length - 1) {
        parts.add(List<double>.filled(gapSamples, 0));
        total += gapSamples;
      }
    }
    final mixed = Float64List(total);
    var offset = 0;
    for (final part in parts) {
      mixed.setRange(offset, offset + part.length, part);
      offset += part.length;
    }
    return _toWav(mixed);
  }

  /// Renders one note with attack/decay envelope + soft 2nd harmonic.
  static List<double> _renderNote(ToneNote note) {
    final n = (sampleRate * note.ms / 1000).round().clamp(1, 1 << 20);
    final attack = (sampleRate * 0.008).round().clamp(1, n);
    final out = List<double>.filled(n, 0);
    for (var i = 0; i < n; i++) {
      final t = i / sampleRate;
      final fundamental = math.sin(2 * math.pi * note.freqHz * t);
      final harmonic = 0.2 * math.sin(4 * math.pi * note.freqHz * t);
      var env = 1.0;
      if (i < attack) {
        env = i / attack; // click-free attack
      } else {
        // exponential decay to ~5% by note end
        env = math.exp(-3.0 * (i - attack) / (n - attack).clamp(1, n));
      }
      out[i] = (fundamental + harmonic) * env * note.volume.clamp(0.0, 1.0);
    }
    return out;
  }

  /// Encodes float samples (-1..1) as 16-bit mono WAV bytes.
  static Uint8List _toWav(Float64List samples) {
    final dataSize = samples.length * 2;
    final bytes = ByteData(44 + dataSize);
    // RIFF header
    bytes.setUint8(0, 0x52); // R
    bytes.setUint8(1, 0x49); // I
    bytes.setUint8(2, 0x46); // F
    bytes.setUint8(3, 0x46); // F
    bytes.setUint32(4, 36 + dataSize, Endian.little);
    bytes.setUint8(8, 0x57); // W
    bytes.setUint8(9, 0x41); // A
    bytes.setUint8(10, 0x56); // V
    bytes.setUint8(11, 0x45); // E
    // fmt chunk
    bytes.setUint8(12, 0x66); // f
    bytes.setUint8(13, 0x6D); // m
    bytes.setUint8(14, 0x74); // t
    bytes.setUint8(15, 0x20); //
    bytes.setUint32(16, 16, Endian.little); // chunk size
    bytes.setUint16(20, 1, Endian.little); // PCM
    bytes.setUint16(22, 1, Endian.little); // mono
    bytes.setUint32(24, sampleRate, Endian.little);
    bytes.setUint32(28, sampleRate * 2, Endian.little); // byte rate
    bytes.setUint16(32, 2, Endian.little); // block align
    bytes.setUint16(34, 16, Endian.little); // bits per sample
    // data chunk
    bytes.setUint8(36, 0x64); // d
    bytes.setUint8(37, 0x61); // a
    bytes.setUint8(38, 0x74); // t
    bytes.setUint8(39, 0x61); // a
    bytes.setUint32(40, dataSize, Endian.little);
    for (var i = 0; i < samples.length; i++) {
      final v = samples[i].clamp(-1.0, 1.0);
      bytes.setInt16(44 + i * 2, (v * 32767).round(), Endian.little);
    }
    return bytes.buffer.asUint8List();
  }
}
