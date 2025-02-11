import '../entities/analytics_data_point.dart';

class ProjectAnalytics {
  final int totalViews;
  final double engagementRate;
  final double viewsChange;
  final double engagementChange;
  final List<AnalyticsDataPoint> viewsData;
  final List<AnalyticsDataPoint> retentionData;
  final Duration averageWatchTime;
  final Duration totalWatchTime;
  final int uniqueViewers;
  final int peakConcurrentViewers;

  const ProjectAnalytics({
    required this.totalViews,
    required this.engagementRate,
    required this.viewsChange,
    required this.engagementChange,
    required this.viewsData,
    required this.retentionData,
    required this.averageWatchTime,
    required this.totalWatchTime,
    required this.uniqueViewers,
    required this.peakConcurrentViewers,
  });
}

abstract class AnalyticsRepository {
  /// Fetches analytics data for a project within the specified date range.
  /// If no date range is provided, returns data for the last 30 days.
  Future<ProjectAnalytics> getProjectAnalytics(
    String projectId, {
    DateTime? startDate,
    DateTime? endDate,
  });

  /// Fetches real-time analytics data for a project.
  Stream<ProjectAnalytics> watchProjectAnalytics(String projectId);

  /// Records a new view for the project.
  Future<void> recordView(String projectId);

  /// Records engagement data for a view session.
  Future<void> recordEngagement({
    required String projectId,
    required Duration watchTime,
    required double completionRate,
    required bool isUnique,
  });

  /// Exports analytics data to a CSV file.
  Future<String> exportAnalytics(
    String projectId, {
    DateTime? startDate,
    DateTime? endDate,
  });
}
