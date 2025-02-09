import 'package:equatable/equatable.dart';
import 'video_quality.dart';

class VideoProcessingConfig extends Equatable {
  final VideoQuality quality;
  final bool shouldCompress;
  final bool maintainAspectRatio;
  final int? maxBitrate; // in kbps
  final double? framerate;
  final String? audioCodec;
  final String? videoCodec;

  const VideoProcessingConfig({
    this.quality = VideoQuality.high,
    this.shouldCompress = true,
    this.maintainAspectRatio = true,
    this.maxBitrate,
    this.framerate,
    this.audioCodec,
    this.videoCodec,
  });

  VideoProcessingConfig copyWith({
    VideoQuality? quality,
    bool? shouldCompress,
    bool? maintainAspectRatio,
    int? maxBitrate,
    double? framerate,
    String? audioCodec,
    String? videoCodec,
  }) {
    return VideoProcessingConfig(
      quality: quality ?? this.quality,
      shouldCompress: shouldCompress ?? this.shouldCompress,
      maintainAspectRatio: maintainAspectRatio ?? this.maintainAspectRatio,
      maxBitrate: maxBitrate ?? this.maxBitrate,
      framerate: framerate ?? this.framerate,
      audioCodec: audioCodec ?? this.audioCodec,
      videoCodec: videoCodec ?? this.videoCodec,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'quality': quality.name,
      'shouldCompress': shouldCompress,
      'maintainAspectRatio': maintainAspectRatio,
      'maxBitrate': maxBitrate,
      'framerate': framerate,
      'audioCodec': audioCodec,
      'videoCodec': videoCodec,
    };
  }

  factory VideoProcessingConfig.fromJson(Map<String, dynamic> json) {
    return VideoProcessingConfig(
      quality: VideoQuality.values.firstWhere(
        (q) => q.name == json['quality'],
        orElse: () => VideoQuality.high,
      ),
      shouldCompress: json['shouldCompress'] ?? true,
      maintainAspectRatio: json['maintainAspectRatio'] ?? true,
      maxBitrate: json['maxBitrate'],
      framerate: json['framerate']?.toDouble(),
      audioCodec: json['audioCodec'],
      videoCodec: json['videoCodec'],
    );
  }

  @override
  List<Object?> get props => [
        quality,
        shouldCompress,
        maintainAspectRatio,
        maxBitrate,
        framerate,
        audioCodec,
        videoCodec,
      ];

  static const VideoProcessingConfig defaultConfig = VideoProcessingConfig(
    quality: VideoQuality.high,
    shouldCompress: true,
    maintainAspectRatio: true,
    maxBitrate: 5000, // 5 Mbps
    framerate: 30,
    audioCodec: 'aac',
    videoCodec: 'h264',
  );
}
