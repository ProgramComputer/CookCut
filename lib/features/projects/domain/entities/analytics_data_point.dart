import 'package:equatable/equatable.dart';

class AnalyticsDataPoint extends Equatable {
  final DateTime date;
  final double value;

  const AnalyticsDataPoint({
    required this.date,
    required this.value,
  });

  @override
  List<Object?> get props => [date, value];

  factory AnalyticsDataPoint.fromJson(Map<String, dynamic> json) {
    return AnalyticsDataPoint(
      date: DateTime.fromMillisecondsSinceEpoch(json['date']),
      value: json['value'].toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'date': date.millisecondsSinceEpoch,
      'value': value,
    };
  }
}
