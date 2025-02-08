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
    required String userId,
    required String title,
    required String description,
    required DateTime createdAt,
    required DateTime updatedAt,
    String? thumbnailUrl,
    int collaboratorsCount = 0,
    ProjectAnalytics? analytics,
  }) {
    return Project._internal(
      id: id,
      userId: userId,
      title: title,
      description: description,
      createdAt: createdAt,
      updatedAt: updatedAt,
      thumbnailUrl: thumbnailUrl,
      collaboratorsCount: collaboratorsCount,
      analytics: analytics ?? ProjectAnalytics.defaultAnalytics,
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

  @override
  List<Object?> get props => [views, engagementRate, _millisecondsSinceEpoch];
}
