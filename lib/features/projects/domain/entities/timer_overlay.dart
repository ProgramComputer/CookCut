import 'package:flutter/material.dart';

class TimerOverlay {
  final String id;
  final int durationSeconds;
  final double x;
  final double y;
  final String color;
  final double fontSize;
  final double startTime;
  final String style;
  final bool showMilliseconds;
  final String backgroundColor;
  final double backgroundOpacity;
  final String alignment;
  final String? label;
  final double scale;
  final double endTime;

  const TimerOverlay({
    required this.id,
    required this.durationSeconds,
    required this.x,
    required this.y,
    required this.color,
    required this.fontSize,
    required this.startTime,
    this.style = 'default',
    this.showMilliseconds = false,
    this.backgroundColor = '#000000',
    this.backgroundOpacity = 0.5,
    this.alignment = 'center',
    this.label,
    this.scale = 1.0,
    this.endTime = 0.0,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': 'timer',
      'durationSeconds': durationSeconds,
      'x': x,
      'y': y,
      'color': color,
      'fontSize': fontSize,
      'startTime': startTime,
      'style': style,
      'showMilliseconds': showMilliseconds,
      'backgroundColor': backgroundColor,
      'backgroundOpacity': backgroundOpacity,
      'alignment': alignment,
      'label': label,
      'scale': scale,
      'endTime': endTime,
    };
  }

  factory TimerOverlay.fromJson(Map<String, dynamic> json) {
    return TimerOverlay(
      id: json['id'] as String,
      durationSeconds: json['durationSeconds'] as int,
      x: json['x'] as double,
      y: json['y'] as double,
      color: json['color'] as String,
      fontSize: json['fontSize'] as double,
      startTime: json['startTime'] as double,
      style: json['style'] as String? ?? 'default',
      showMilliseconds: json['showMilliseconds'] as bool? ?? false,
      backgroundColor: json['backgroundColor'] as String? ?? '#000000',
      backgroundOpacity: json['backgroundOpacity'] as double? ?? 0.5,
      alignment: json['alignment'] as String? ?? 'center',
      label: json['label'] as String?,
      scale: json['scale'] as double? ?? 1.0,
      endTime: json['endTime'] as double? ?? 0.0,
    );
  }

  TimerOverlay copyWith({
    String? id,
    int? durationSeconds,
    double? x,
    double? y,
    String? color,
    double? fontSize,
    double? startTime,
    String? style,
    bool? showMilliseconds,
    String? backgroundColor,
    double? backgroundOpacity,
    String? alignment,
    String? label,
    double? scale,
    double? endTime,
  }) {
    return TimerOverlay(
      id: id ?? this.id,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      x: x ?? this.x,
      y: y ?? this.y,
      color: color ?? this.color,
      fontSize: fontSize ?? this.fontSize,
      startTime: startTime ?? this.startTime,
      style: style ?? this.style,
      showMilliseconds: showMilliseconds ?? this.showMilliseconds,
      backgroundColor: backgroundColor ?? this.backgroundColor,
      backgroundOpacity: backgroundOpacity ?? this.backgroundOpacity,
      alignment: alignment ?? this.alignment,
      label: label ?? this.label,
      scale: scale ?? this.scale,
      endTime: endTime ?? this.endTime,
    );
  }
}
