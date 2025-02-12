import 'package:flutter/material.dart';

class TextOverlay {
  final String id;
  final String text;
  final double x;
  final double y;
  final String color;
  final double fontSize;
  final double startTime;
  final double endTime;
  final String fontFamily;
  final bool isBold;
  final bool isItalic;
  final String backgroundColor;
  final double backgroundOpacity;
  final String alignment;
  final double scale;
  final double rotation;

  const TextOverlay({
    required this.id,
    required this.text,
    required this.x,
    required this.y,
    required this.color,
    required this.fontSize,
    required this.startTime,
    required this.endTime,
    this.fontFamily = 'Arial',
    this.isBold = false,
    this.isItalic = false,
    this.backgroundColor = '#000000',
    this.backgroundOpacity = 0.5,
    this.alignment = 'center',
    this.scale = 1.0,
    this.rotation = 0.0,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': 'text',
      'text': text,
      'x': x,
      'y': y,
      'color': color,
      'fontSize': fontSize,
      'startTime': startTime,
      'endTime': endTime,
      'fontFamily': fontFamily,
      'isBold': isBold,
      'isItalic': isItalic,
      'backgroundColor': backgroundColor,
      'backgroundOpacity': backgroundOpacity,
      'alignment': alignment,
      'scale': scale,
      'rotation': rotation,
    };
  }

  factory TextOverlay.fromJson(Map<String, dynamic> json) {
    return TextOverlay(
      id: json['id'] as String,
      text: json['text'] as String,
      x: json['x'] as double,
      y: json['y'] as double,
      color: json['color'] as String,
      fontSize: json['fontSize'] as double,
      startTime: json['startTime'] as double,
      endTime: json['endTime'] as double,
      fontFamily: json['fontFamily'] as String? ?? 'Arial',
      isBold: json['isBold'] as bool? ?? false,
      isItalic: json['isItalic'] as bool? ?? false,
      backgroundColor: json['backgroundColor'] as String? ?? '#000000',
      backgroundOpacity: json['backgroundOpacity'] as double? ?? 0.5,
      alignment: json['alignment'] as String? ?? 'center',
      scale: json['scale'] as double? ?? 1.0,
      rotation: json['rotation'] as double? ?? 0.0,
    );
  }

  TextOverlay copyWith({
    String? id,
    String? text,
    double? x,
    double? y,
    String? color,
    double? fontSize,
    double? startTime,
    double? endTime,
    String? fontFamily,
    bool? isBold,
    bool? isItalic,
    String? backgroundColor,
    double? backgroundOpacity,
    String? alignment,
    double? scale,
    double? rotation,
  }) {
    return TextOverlay(
      id: id ?? this.id,
      text: text ?? this.text,
      x: x ?? this.x,
      y: y ?? this.y,
      color: color ?? this.color,
      fontSize: fontSize ?? this.fontSize,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      fontFamily: fontFamily ?? this.fontFamily,
      isBold: isBold ?? this.isBold,
      isItalic: isItalic ?? this.isItalic,
      backgroundColor: backgroundColor ?? this.backgroundColor,
      backgroundOpacity: backgroundOpacity ?? this.backgroundOpacity,
      alignment: alignment ?? this.alignment,
      scale: scale ?? this.scale,
      rotation: rotation ?? this.rotation,
    );
  }
}
