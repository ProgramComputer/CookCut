import 'package:flutter/material.dart';
import 'text_overlay.dart';
import 'timer_overlay.dart';

abstract class VideoOverlayModel {
  final String id;
  final Offset position;
  final String color;
  final double fontSize;
  final double startTime;
  final String type;

  VideoOverlayModel({
    required this.id,
    required this.position,
    required this.color,
    required this.fontSize,
    required this.startTime,
    required this.type,
  });

  Map<String, dynamic> toJson();

  static VideoOverlayModel fromJson(Map<String, dynamic> json) {
    final type = json['type'] as String;
    switch (type) {
      case 'text':
        return TextOverlayModel.fromJson(json);
      case 'timer':
        return TimerOverlayModel.fromJson(json);
      default:
        throw ArgumentError('Unknown overlay type: $type');
    }
  }

  TextOverlayModel? toTextOverlay() {
    return this is TextOverlayModel ? this as TextOverlayModel : null;
  }

  TimerOverlayModel? toTimerOverlay() {
    return this is TimerOverlayModel ? this as TimerOverlayModel : null;
  }
}

class TextOverlayModel extends VideoOverlayModel {
  final String text;
  final double endTime;

  TextOverlayModel({
    required String id,
    required this.text,
    required Offset position,
    required String color,
    required double fontSize,
    required double startTime,
    required this.endTime,
  }) : super(
          id: id,
          position: position,
          color: color,
          fontSize: fontSize,
          startTime: startTime,
          type: 'text',
        );

  @override
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': 'text',
      'text': text,
      'x': position.dx,
      'y': position.dy,
      'color': color,
      'fontSize': fontSize,
      'startTime': startTime,
      'endTime': endTime,
    };
  }

  factory TextOverlayModel.fromJson(Map<String, dynamic> json) {
    return TextOverlayModel(
      id: json['id'] as String,
      text: json['text'] as String,
      position: Offset(
        json['x'] as double,
        json['y'] as double,
      ),
      color: json['color'] as String,
      fontSize: json['fontSize'] as double,
      startTime: json['startTime'] as double,
      endTime: json['endTime'] as double,
    );
  }

  TextOverlayModel copyWith({
    String? id,
    String? text,
    Offset? position,
    String? color,
    double? fontSize,
    double? startTime,
    double? endTime,
  }) {
    return TextOverlayModel(
      id: id ?? this.id,
      text: text ?? this.text,
      position: position ?? this.position,
      color: color ?? this.color,
      fontSize: fontSize ?? this.fontSize,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
    );
  }
}

class TimerOverlayModel extends VideoOverlayModel {
  final int durationSeconds;

  TimerOverlayModel({
    required String id,
    required this.durationSeconds,
    required Offset position,
    required String color,
    required double fontSize,
    required double startTime,
  }) : super(
          id: id,
          position: position,
          color: color,
          fontSize: fontSize,
          startTime: startTime,
          type: 'timer',
        );

  @override
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': 'timer',
      'durationSeconds': durationSeconds,
      'x': position.dx,
      'y': position.dy,
      'color': color,
      'fontSize': fontSize,
      'startTime': startTime,
    };
  }

  factory TimerOverlayModel.fromJson(Map<String, dynamic> json) {
    return TimerOverlayModel(
      id: json['id'] as String,
      durationSeconds: json['durationSeconds'] as int,
      position: Offset(
        json['x'] as double,
        json['y'] as double,
      ),
      color: json['color'] as String,
      fontSize: json['fontSize'] as double,
      startTime: json['startTime'] as double,
    );
  }

  TimerOverlayModel copyWith({
    String? id,
    int? durationSeconds,
    Offset? position,
    String? color,
    double? fontSize,
    double? startTime,
  }) {
    return TimerOverlayModel(
      id: id ?? this.id,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      position: position ?? this.position,
      color: color ?? this.color,
      fontSize: fontSize ?? this.fontSize,
      startTime: startTime ?? this.startTime,
    );
  }
}
