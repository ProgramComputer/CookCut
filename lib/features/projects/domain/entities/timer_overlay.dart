import 'package:equatable/equatable.dart';

class TimerOverlay extends Equatable {
  final String id;
  final int durationSeconds;
  final double startTime;
  final double x;
  final double y;
  final double scale;
  final String style; // 'minimal', 'standard', 'detailed'
  final String color;
  final bool showMilliseconds;
  final String backgroundColor;
  final double backgroundOpacity;
  final String alignment;
  final String? label;

  const TimerOverlay({
    required this.id,
    required this.durationSeconds,
    required this.startTime,
    required this.x,
    required this.y,
    this.scale = 1.0,
    this.style = 'standard',
    this.color = '#FFFFFF',
    this.showMilliseconds = false,
    this.backgroundColor = '#000000',
    this.backgroundOpacity = 0.5,
    this.alignment = 'center',
    this.label,
  });

  double get endTime => startTime + durationSeconds;

  TimerOverlay copyWith({
    int? durationSeconds,
    double? startTime,
    double? x,
    double? y,
    double? scale,
    String? style,
    String? color,
    bool? showMilliseconds,
    String? backgroundColor,
    double? backgroundOpacity,
    String? alignment,
    String? label,
  }) {
    return TimerOverlay(
      id: id,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      startTime: startTime ?? this.startTime,
      x: x ?? this.x,
      y: y ?? this.y,
      scale: scale ?? this.scale,
      style: style ?? this.style,
      color: color ?? this.color,
      showMilliseconds: showMilliseconds ?? this.showMilliseconds,
      backgroundColor: backgroundColor ?? this.backgroundColor,
      backgroundOpacity: backgroundOpacity ?? this.backgroundOpacity,
      alignment: alignment ?? this.alignment,
      label: label ?? this.label,
    );
  }

  @override
  List<Object?> get props => [
        id,
        durationSeconds,
        startTime,
        x,
        y,
        scale,
        style,
        color,
        showMilliseconds,
        backgroundColor,
        backgroundOpacity,
        alignment,
        label,
      ];
}
