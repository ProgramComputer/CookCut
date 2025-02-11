import 'package:equatable/equatable.dart';

class VideoComment extends Equatable {
  final String id;
  final String projectId;
  final String assetId;
  final String authorId;
  final String authorName;
  final String? authorAvatarUrl;
  final String text;
  final Duration timestamp;
  final DateTime createdAt;
  final DateTime? updatedAt;

  const VideoComment({
    required this.id,
    required this.projectId,
    required this.assetId,
    required this.authorId,
    required this.authorName,
    this.authorAvatarUrl,
    required this.text,
    required this.timestamp,
    required this.createdAt,
    this.updatedAt,
  });

  @override
  List<Object?> get props => [
        id,
        projectId,
        assetId,
        authorId,
        authorName,
        authorAvatarUrl,
        text,
        timestamp,
        createdAt,
        updatedAt,
      ];

  VideoComment copyWith({
    String? id,
    String? projectId,
    String? assetId,
    String? authorId,
    String? authorName,
    String? authorAvatarUrl,
    String? text,
    Duration? timestamp,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return VideoComment(
      id: id ?? this.id,
      projectId: projectId ?? this.projectId,
      assetId: assetId ?? this.assetId,
      authorId: authorId ?? this.authorId,
      authorName: authorName ?? this.authorName,
      authorAvatarUrl: authorAvatarUrl ?? this.authorAvatarUrl,
      text: text ?? this.text,
      timestamp: timestamp ?? this.timestamp,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
