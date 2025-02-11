import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../domain/entities/analytics_data_point.dart';
import 'package:intl/intl.dart';

class EngagementChart extends StatelessWidget {
  final List<AnalyticsDataPoint> data;
  final Color color;

  const EngagementChart({
    super.key,
    required this.data,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) {
      return const Center(
        child: Text('No data available'),
      );
    }

    final maxY = data.map((e) => e.value).reduce((a, b) => a > b ? a : b);
    final minDate = data.first.date;
    final maxDate = data.last.date;

    return Padding(
      padding: const EdgeInsets.only(
        left: 16,
        right: 16,
        bottom: 16,
        top: 16,
      ),
      child: LineChart(
        LineChartData(
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: maxY / 5,
            getDrawingHorizontalLine: (value) {
              return FlLine(
                color: Theme.of(context).colorScheme.surfaceVariant,
                strokeWidth: 1,
              );
            },
          ),
          titlesData: FlTitlesData(
            show: true,
            rightTitles: AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            topTitles: AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 30,
                interval:
                    (maxDate.difference(minDate).inDays / 4).ceil().toDouble(),
                getTitlesWidget: (value, meta) {
                  final date = minDate.add(Duration(days: value.toInt()));
                  return Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text(
                      DateFormat.MMMd().format(date),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  );
                },
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                interval: maxY / 5,
                reservedSize: 40,
                getTitlesWidget: (value, meta) {
                  return Text(
                    NumberFormat.compact().format(value),
                    style: Theme.of(context).textTheme.bodySmall,
                  );
                },
              ),
            ),
          ),
          borderData: FlBorderData(
            show: false,
          ),
          minX: 0,
          maxX: maxDate.difference(minDate).inDays.toDouble(),
          minY: 0,
          maxY: maxY * 1.1,
          lineBarsData: [
            LineChartBarData(
              spots: data.map((point) {
                return FlSpot(
                  point.date.difference(minDate).inDays.toDouble(),
                  point.value.toDouble(),
                );
              }).toList(),
              isCurved: true,
              color: color,
              barWidth: 3,
              isStrokeCapRound: true,
              dotData: FlDotData(
                show: false,
              ),
              belowBarData: BarAreaData(
                show: true,
                color: color.withOpacity(0.1),
              ),
            ),
          ],
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              fitInsideHorizontally: true,
              fitInsideVertically: true,
              tooltipMargin: 8,
              tooltipHorizontalOffset: 0,
              tooltipPadding: const EdgeInsets.all(8),
              tooltipRoundedRadius: 4,
              showOnTopOfTheChartBoxArea: true,
              tooltipBorder: BorderSide.none,
              getTooltipColor: (touchedSpot) =>
                  Theme.of(context).colorScheme.surface.withOpacity(0.8),
              getTooltipItems: (touchedSpots) {
                return touchedSpots.map((spot) {
                  final date = minDate.add(Duration(days: spot.x.toInt()));
                  return LineTooltipItem(
                    '${NumberFormat.compact().format(spot.y)} views\n${DateFormat.yMMMd().format(date)}',
                    Theme.of(context).textTheme.bodySmall!.copyWith(
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                  );
                }).toList();
              },
            ),
            handleBuiltInTouches: true,
            getTouchLineStart: (data, index) => 0,
          ),
        ),
      ),
    );
  }
}
