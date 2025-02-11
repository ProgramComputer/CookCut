import 'package:flutter/material.dart';

class AnalyticsMetricsGrid extends StatelessWidget {
  final Duration averageWatchTime;
  final Duration totalWatchTime;
  final int uniqueViewers;
  final int peakConcurrentViewers;

  const AnalyticsMetricsGrid({
    super.key,
    required this.averageWatchTime,
    required this.totalWatchTime,
    required this.uniqueViewers,
    required this.peakConcurrentViewers,
  });

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Detailed Metrics',
              style: textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 16,
              crossAxisSpacing: 16,
              childAspectRatio: 1.5,
              children: [
                _MetricCard(
                  label: 'Average Watch Time',
                  value: _formatDuration(averageWatchTime),
                  icon: Icons.timer_outlined,
                  iconColor: colorScheme.primary,
                ),
                _MetricCard(
                  label: 'Total Watch Time',
                  value: _formatDuration(totalWatchTime),
                  icon: Icons.schedule_outlined,
                  iconColor: colorScheme.secondary,
                ),
                _MetricCard(
                  label: 'Unique Viewers',
                  value: uniqueViewers.toString(),
                  icon: Icons.person_outline,
                  iconColor: colorScheme.tertiary,
                ),
                _MetricCard(
                  label: 'Peak Concurrent',
                  value: peakConcurrentViewers.toString(),
                  icon: Icons.groups_outlined,
                  iconColor: colorScheme.error,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color iconColor;

  const _MetricCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Icon(icon, color: iconColor, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  style: textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
