import 'package:equatable/equatable.dart';

enum MediaType { rawFootage, editedClip, audio }

class MediaAsset extends Equatable {
  final String id;
  final String projectId;
  final MediaType type;
  final String fileUrl;
  final String? thumbnailUrl;
  final String fileName;
  final int fileSize;
  final Duration? duration;
  final DateTime uploadedAt;
  final Map<String, dynamic> metadata;

  const MediaAsset({
    required this.id,
    required this.projectId,
    required this.type,
    required this.fileUrl,
    required this.fileName,
    required this.fileSize,
    required this.uploadedAt,
    this.thumbnailUrl,
    this.duration,
    this.metadata = const {},
  });

  @override
  List<Object?> get props => [
        id,
        projectId,
        type,
        fileUrl,
        thumbnailUrl,
        fileName,
        fileSize,
        duration,
        uploadedAt,
        metadata,
      ];

  String get formattedFileSize {
    if (fileSize < 1024) return '$fileSize B';
    if (fileSize < 1024 * 1024) {
      return '${(fileSize / 1024).toStringAsFixed(1)} KB';
    }
    if (fileSize < 1024 * 1024 * 1024) {
      return '${(fileSize / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(fileSize / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  String get formattedDuration {
    if (duration == null) return '';
    final minutes = duration!.inMinutes;
    final seconds = duration!.inSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }
}
