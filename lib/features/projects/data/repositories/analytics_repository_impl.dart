import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../domain/repositories/analytics_repository.dart';
import '../../domain/entities/analytics_data_point.dart';
import 'package:csv/csv.dart';

class AnalyticsRepositoryImpl implements AnalyticsRepository {
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  AnalyticsRepositoryImpl({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  @override
  Future<ProjectAnalytics> getProjectAnalytics(
    String projectId, {
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final now = DateTime.now();
    final effectiveStartDate =
        startDate ?? now.subtract(const Duration(days: 30));
    final effectiveEndDate = endDate ?? now;

    // Get analytics data for the current period
    final currentPeriodData = await _getAnalyticsData(
      projectId,
      effectiveStartDate,
      effectiveEndDate,
    );

    // Get analytics data for the previous period for comparison
    final previousPeriodDuration =
        effectiveEndDate.difference(effectiveStartDate);
    final previousPeriodStartDate =
        effectiveStartDate.subtract(previousPeriodDuration);
    final previousPeriodEndDate = effectiveStartDate;

    final previousPeriodData = await _getAnalyticsData(
      projectId,
      previousPeriodStartDate,
      previousPeriodEndDate,
    );

    // Calculate changes
    final viewsChange = _calculatePercentageChange(
      previousPeriodData.totalViews,
      currentPeriodData.totalViews,
    );
    final engagementChange = _calculatePercentageChange(
      previousPeriodData.engagementRate,
      currentPeriodData.engagementRate,
    );

    return ProjectAnalytics(
      totalViews: currentPeriodData.totalViews,
      engagementRate: currentPeriodData.engagementRate,
      viewsChange: viewsChange,
      engagementChange: engagementChange,
      viewsData: currentPeriodData.viewsData,
      retentionData: currentPeriodData.retentionData,
      averageWatchTime: currentPeriodData.averageWatchTime,
      totalWatchTime: currentPeriodData.totalWatchTime,
      uniqueViewers: currentPeriodData.uniqueViewers,
      peakConcurrentViewers: currentPeriodData.peakConcurrentViewers,
    );
  }

  @override
  Stream<ProjectAnalytics> watchProjectAnalytics(String projectId) {
    final now = DateTime.now();
    final startDate = now.subtract(const Duration(days: 30));

    return _firestore
        .collection('projects')
        .doc(projectId)
        .collection('analytics')
        .where('timestamp',
            isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
        .snapshots()
        .map((snapshot) {
      final data = _processAnalyticsSnapshot(snapshot);
      return ProjectAnalytics(
        totalViews: data.totalViews,
        engagementRate: data.engagementRate,
        viewsChange: 0, // Real-time changes not calculated
        engagementChange: 0, // Real-time changes not calculated
        viewsData: data.viewsData,
        retentionData: data.retentionData,
        averageWatchTime: data.averageWatchTime,
        totalWatchTime: data.totalWatchTime,
        uniqueViewers: data.uniqueViewers,
        peakConcurrentViewers: data.peakConcurrentViewers,
      );
    });
  }

  @override
  Future<void> recordView(String projectId) async {
    final user = _auth.currentUser;
    if (user == null) return;

    final analyticsRef = _firestore
        .collection('projects')
        .doc(projectId)
        .collection('analytics')
        .doc(DateTime.now().toIso8601String());

    await analyticsRef.set({
      'type': 'view',
      'userId': user.uid,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  @override
  Future<void> recordEngagement({
    required String projectId,
    required Duration watchTime,
    required double completionRate,
    required bool isUnique,
  }) async {
    final user = _auth.currentUser;
    if (user == null) return;

    final analyticsRef = _firestore
        .collection('projects')
        .doc(projectId)
        .collection('analytics')
        .doc(DateTime.now().toIso8601String());

    await analyticsRef.set({
      'type': 'engagement',
      'userId': user.uid,
      'watchTime': watchTime.inSeconds,
      'completionRate': completionRate,
      'isUnique': isUnique,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  @override
  Future<String> exportAnalytics(
    String projectId, {
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final analytics = await getProjectAnalytics(
      projectId,
      startDate: startDate,
      endDate: endDate,
    );

    final csvData = [
      ['Date', 'Views', 'Engagement Rate', 'Watch Time (seconds)'],
      ...analytics.viewsData.map((point) => [
            point.date.toIso8601String(),
            point.value.toInt(),
            analytics.engagementRate,
            analytics.averageWatchTime.inSeconds,
          ]),
    ];

    return const ListToCsvConverter().convert(csvData);
  }

  Future<ProjectAnalytics> _getAnalyticsData(
    String projectId,
    DateTime startDate,
    DateTime endDate,
  ) async {
    final snapshot = await _firestore
        .collection('projects')
        .doc(projectId)
        .collection('analytics')
        .where('timestamp',
            isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
        .where('timestamp', isLessThanOrEqualTo: Timestamp.fromDate(endDate))
        .get();

    return _processAnalyticsSnapshot(snapshot);
  }

  ProjectAnalytics _processAnalyticsSnapshot(
      QuerySnapshot<Map<String, dynamic>> snapshot) {
    final viewDocs =
        snapshot.docs.where((doc) => doc.data()['type'] == 'view').toList();
    final engagementDocs = snapshot.docs
        .where((doc) => doc.data()['type'] == 'engagement')
        .toList();

    // Process views
    final viewsData = _processViewsData(viewDocs);
    final totalViews = viewDocs.length;
    final uniqueViewers =
        viewDocs.map((doc) => doc.data()['userId']).toSet().length;

    // Process engagement
    final totalWatchTime = _calculateTotalWatchTime(engagementDocs);
    final averageWatchTime = engagementDocs.isEmpty
        ? Duration.zero
        : Duration(
            seconds: totalWatchTime.inSeconds ~/ engagementDocs.length,
          );
    final engagementRate = _calculateEngagementRate(engagementDocs);
    final retentionData = _processRetentionData(engagementDocs);

    // Calculate peak concurrent viewers
    final peakConcurrentViewers = _calculatePeakConcurrentViewers(viewDocs);

    return ProjectAnalytics(
      totalViews: totalViews,
      engagementRate: engagementRate,
      viewsChange: 0,
      engagementChange: 0,
      viewsData: viewsData,
      retentionData: retentionData,
      averageWatchTime: averageWatchTime,
      totalWatchTime: totalWatchTime,
      uniqueViewers: uniqueViewers,
      peakConcurrentViewers: peakConcurrentViewers,
    );
  }

  List<AnalyticsDataPoint> _processViewsData(
      List<QueryDocumentSnapshot<Map<String, dynamic>>> docs) {
    // Group views by day
    final viewsByDay = <DateTime, int>{};
    for (final doc in docs) {
      final timestamp = (doc.data()['timestamp'] as Timestamp).toDate();
      final date = DateTime(timestamp.year, timestamp.month, timestamp.day);
      viewsByDay[date] = (viewsByDay[date] ?? 0) + 1;
    }

    // Convert to sorted list of data points
    final dataPoints = viewsByDay.entries
        .map((entry) => AnalyticsDataPoint(
              date: entry.key,
              value: entry.value.toDouble(),
            ))
        .toList();
    dataPoints.sort((a, b) => a.date.compareTo(b.date));

    return dataPoints;
  }

  List<AnalyticsDataPoint> _processRetentionData(
      List<QueryDocumentSnapshot<Map<String, dynamic>>> docs) {
    if (docs.isEmpty) return [];

    // Group completion rates into 100 segments
    final segments = List.filled(100, 0.0);
    final counts = List.filled(100, 0);

    for (final doc in docs) {
      final completionRate = doc.data()['completionRate'] as double;
      final segment = (completionRate * 99).floor();
      segments[segment] += completionRate;
      counts[segment]++;
    }

    // Calculate average retention for each segment
    return List.generate(100, (index) {
      final count = counts[index];
      return AnalyticsDataPoint(
        date: DateTime.now(), // Date not relevant for retention
        value: count > 0 ? segments[index] / count : 0,
      );
    });
  }

  Duration _calculateTotalWatchTime(
      List<QueryDocumentSnapshot<Map<String, dynamic>>> docs) {
    final totalSeconds = docs.fold<int>(
        0, (sum, doc) => sum + (doc.data()['watchTime'] as num).toInt());
    return Duration(seconds: totalSeconds);
  }

  double _calculateEngagementRate(
      List<QueryDocumentSnapshot<Map<String, dynamic>>> docs) {
    if (docs.isEmpty) return 0.0;

    final totalCompletionRate = docs.fold<double>(0.0,
        (sum, doc) => sum + (doc.data()['completionRate'] as num).toDouble());
    return totalCompletionRate / docs.length;
  }

  int _calculatePeakConcurrentViewers(
      List<QueryDocumentSnapshot<Map<String, dynamic>>> docs) {
    if (docs.isEmpty) return 0;

    // Group views by minute
    final viewsByMinute = <DateTime, int>{};
    for (final doc in docs) {
      final timestamp = (doc.data()['timestamp'] as Timestamp).toDate();
      final minute = DateTime(
        timestamp.year,
        timestamp.month,
        timestamp.day,
        timestamp.hour,
        timestamp.minute,
      );
      viewsByMinute[minute] = (viewsByMinute[minute] ?? 0) + 1;
    }

    return viewsByMinute.values.reduce((a, b) => a > b ? a : b);
  }

  double _calculatePercentageChange(num previous, num current) {
    if (previous == 0) return current > 0 ? 100 : 0;
    return ((current - previous) / previous) * 100;
  }
}
