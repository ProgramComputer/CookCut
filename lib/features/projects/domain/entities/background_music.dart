import 'package:equatable/equatable.dart';

class BackgroundMusic extends Equatable {
  final String id;
  final String projectId;
  final String url;
  final String title;
  final String? artist;
  final double volume;
  final double startTime;
  final double endTime;
  final DateTime createdAt;
  final DateTime updatedAt;

  const BackgroundMusic({
    required this.id,
    required this.projectId,
    required this.url,
    required this.title,
    this.artist,
    this.volume = 1.0,
    this.startTime = 0.0,
    this.endTime = 0.0,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'project_id': projectId,
      'url': url,
      'title': title,
      'artist': artist,
      'volume': volume,
      'start_time': startTime,
      'end_time': endTime,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory BackgroundMusic.fromJson(Map<String, dynamic> json) {
    return BackgroundMusic(
      id: json['id'] as String,
      projectId: json['project_id'] as String,
      url: json['url'] as String,
      title: json['title'] as String,
      artist: json['artist'] as String?,
      volume: (json['volume'] as num?)?.toDouble() ?? 1.0,
      startTime: (json['start_time'] as num?)?.toDouble() ?? 0.0,
      endTime: (json['end_time'] as num?)?.toDouble() ?? 0.0,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  @override
  List<Object?> get props => [
        id,
        projectId,
        url,
        title,
        artist,
        volume,
        startTime,
        endTime,
        createdAt,
        updatedAt,
      ];
}
