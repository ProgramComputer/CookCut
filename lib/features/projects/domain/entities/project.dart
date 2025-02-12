import 'package:equatable/equatable.dart';

class Project extends Equatable {
  final String id;
  final String userId;
  final String title;
  final String description;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? thumbnailUrl;
  final int collaboratorsCount;
  final ProjectAnalytics analytics;

  const Project._internal({
    required this.id,
    required this.userId,
    required this.title,
    required this.description,
    required this.createdAt,
    required this.updatedAt,
    required this.analytics,
    this.thumbnailUrl,
    this.collaboratorsCount = 0,
  });

  factory Project({
    required String id,
    String userId = '',
    String title = '',
    String description = '',
    DateTime? createdAt,
    DateTime? updatedAt,
    String? thumbnailUrl,
    int collaboratorsCount = 0,
    ProjectAnalytics? analytics,
  }) {
    return Project._internal(
      id: id,
      userId: userId,
      title: title,
      description: description,
      createdAt: createdAt ?? DateTime.now(),
      updatedAt: updatedAt ?? DateTime.now(),
      thumbnailUrl: thumbnailUrl,
      collaboratorsCount: collaboratorsCount,
      analytics: analytics ?? ProjectAnalytics.defaultAnalytics,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'title': title,
      'description': description,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'thumbnailUrl': thumbnailUrl,
      'collaboratorsCount': collaboratorsCount,
      'analytics': analytics.toJson(),
    };
  }

  factory Project.fromJson(Map<String, dynamic> json) {
    return Project(
      id: json['id'] as String,
      userId: json['userId'] as String? ?? '',
      title: json['title'] as String? ?? '',
      description: json['description'] as String? ?? '',
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? ''),
      updatedAt: DateTime.tryParse(json['updatedAt'] as String? ?? ''),
      thumbnailUrl: json['thumbnailUrl'] as String?,
      collaboratorsCount: json['collaboratorsCount'] as int? ?? 0,
      analytics: json['analytics'] != null
          ? ProjectAnalytics.fromJson(json['analytics'] as Map<String, dynamic>)
          : null,
    );
  }

  @override
  List<Object?> get props => [
        id,
        userId,
        title,
        description,
        createdAt,
        updatedAt,
        thumbnailUrl,
        collaboratorsCount,
        analytics,
      ];
}

class ProjectAnalytics extends Equatable {
  static const defaultAnalytics = ProjectAnalytics._(
    views: 0,
    engagementRate: 0.0,
    millisecondsSinceEpoch: 1704067200000, // Jan 1, 2024
  );

  final int views;
  final double engagementRate;
  final int _millisecondsSinceEpoch;

  DateTime get lastUpdated =>
      DateTime.fromMillisecondsSinceEpoch(_millisecondsSinceEpoch);

  const ProjectAnalytics._({
    this.views = 0,
    this.engagementRate = 0.0,
    required int millisecondsSinceEpoch,
  }) : _millisecondsSinceEpoch = millisecondsSinceEpoch;

  factory ProjectAnalytics({
    int views = 0,
    double engagementRate = 0.0,
    DateTime? lastUpdated,
  }) {
    return ProjectAnalytics._(
      views: views,
      engagementRate: engagementRate,
      millisecondsSinceEpoch:
          (lastUpdated ?? DateTime(2024)).millisecondsSinceEpoch,
    );
  }

  factory ProjectAnalytics.now() {
    return ProjectAnalytics(lastUpdated: DateTime.now());
  }

  Map<String, dynamic> toJson() {
    return {
      'views': views,
      'engagementRate': engagementRate,
      'millisecondsSinceEpoch': _millisecondsSinceEpoch,
    };
  }

  factory ProjectAnalytics.fromJson(Map<String, dynamic> json) {
    final millisecondsSinceEpoch = json['millisecondsSinceEpoch'] as int? ?? 0;
    return ProjectAnalytics(
      views: json['views'] as int? ?? 0,
      engagementRate: json['engagementRate'] as double? ?? 0.0,
      lastUpdated: DateTime.fromMillisecondsSinceEpoch(millisecondsSinceEpoch),
    );
  }

  @override
  List<Object?> get props => [views, engagementRate, _millisecondsSinceEpoch];
}
