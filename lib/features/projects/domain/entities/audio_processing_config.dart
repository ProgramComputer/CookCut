class AudioProcessingConfig {
  /// The target decibel level for audio normalization
  final double targetDecibels;

  /// The strength of noise reduction (0.0 to 1.0)
  final double noiseReductionStrength;

  /// The sample rate for audio processing
  final int sampleRate;

  /// The bit rate for audio processing
  final int bitRate;

  const AudioProcessingConfig({
    this.targetDecibels = -23.0,
    this.noiseReductionStrength = 0.5,
    this.sampleRate = 44100,
    this.bitRate = 128000,
  });

  AudioProcessingConfig copyWith({
    double? targetDecibels,
    double? noiseReductionStrength,
    int? sampleRate,
    int? bitRate,
  }) {
    return AudioProcessingConfig(
      targetDecibels: targetDecibels ?? this.targetDecibels,
      noiseReductionStrength:
          noiseReductionStrength ?? this.noiseReductionStrength,
      sampleRate: sampleRate ?? this.sampleRate,
      bitRate: bitRate ?? this.bitRate,
    );
  }
}
