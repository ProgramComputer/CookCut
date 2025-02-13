import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/entities/project.dart';
import '../bloc/analytics_bloc.dart';
import '../widgets/analytics_overview_card.dart';
import '../widgets/engagement_chart.dart';
import '../widgets/viewer_retention_chart.dart';
import '../widgets/analytics_metrics_grid.dart';

class AnalyticsPage extends StatelessWidget {
  final Project project;

  const AnalyticsPage({
    super.key,
    required this.project,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Analytics',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: Theme.of(context).colorScheme.onBackground,
              ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_today_outlined),
            onPressed: () {
              // TODO: Implement date range picker
            },
            tooltip: 'Select Date Range',
          ),
          IconButton(
            icon: const Icon(Icons.share_outlined),
            onPressed: () {
              // TODO: Implement analytics sharing
            },
            tooltip: 'Share Analytics',
          ),
        ],
      ),
      body: BlocBuilder<AnalyticsBloc, AnalyticsState>(
        builder: (context, state) {
          if (state.status == AnalyticsStatus.loading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (state.status == AnalyticsStatus.error) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.error_outline,
                    size: 48,
                    color: Colors.red,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Failed to load analytics',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () {
                      context.read<AnalyticsBloc>().add(
                            LoadAnalytics(project.id),
                          );
                    },
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () async {
              context.read<AnalyticsBloc>().add(LoadAnalytics(project.id));
            },
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                AnalyticsOverviewCard(
                  views: state.totalViews,
                  engagementRate: state.engagementRate,
                  viewsChange: state.viewsChange,
                  engagementChange: state.engagementChange,
                ),
                const SizedBox(height: 16),
                Card(
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text(
                          'Views Over Time',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                      SizedBox(
                        height: 240,
                        child: EngagementChart(
                          data: state.viewsData,
                          color: colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Card(
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text(
                          'Viewer Retention',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                      SizedBox(
                        height: 240,
                        child: ViewerRetentionChart(
                          data: state.retentionData,
                          color: colorScheme.secondary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                AnalyticsMetricsGrid(
                  averageWatchTime: state.averageWatchTime,
                  totalWatchTime: state.totalWatchTime,
                  uniqueViewers: state.uniqueViewers,
                  peakConcurrentViewers: state.peakConcurrentViewers,
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
