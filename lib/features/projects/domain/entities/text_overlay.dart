import 'package:equatable/equatable.dart';

class TextOverlay extends Equatable {
  final String id;
  final String text;
  final double startTime;
  final double endTime;
  final double x;
  final double y;
  final double scale;
  final double rotation;
  final String fontFamily;
  final double fontSize;
  final String color;
  final bool isBold;
  final bool isItalic;
  final String backgroundColor;
  final double backgroundOpacity;
  final String alignment;

  const TextOverlay({
    required this.id,
    required this.text,
    required this.startTime,
    required this.endTime,
    required this.x,
    required this.y,
    this.scale = 1.0,
    this.rotation = 0.0,
    this.fontFamily = 'Inter',
    this.fontSize = 24.0,
    this.color = '#FFFFFF',
    this.isBold = false,
    this.isItalic = false,
    this.backgroundColor = '#000000',
    this.backgroundOpacity = 0.5,
    this.alignment = 'center',
  });

  TextOverlay copyWith({
    String? text,
    double? startTime,
    double? endTime,
    double? x,
    double? y,
    double? scale,
    double? rotation,
    String? fontFamily,
    double? fontSize,
    String? color,
    bool? isBold,
    bool? isItalic,
    String? backgroundColor,
    double? backgroundOpacity,
    String? alignment,
  }) {
    return TextOverlay(
      id: id,
      text: text ?? this.text,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      x: x ?? this.x,
      y: y ?? this.y,
      scale: scale ?? this.scale,
      rotation: rotation ?? this.rotation,
      fontFamily: fontFamily ?? this.fontFamily,
      fontSize: fontSize ?? this.fontSize,
      color: color ?? this.color,
      isBold: isBold ?? this.isBold,
      isItalic: isItalic ?? this.isItalic,
      backgroundColor: backgroundColor ?? this.backgroundColor,
      backgroundOpacity: backgroundOpacity ?? this.backgroundOpacity,
      alignment: alignment ?? this.alignment,
    );
  }

  @override
  List<Object?> get props => [
        id,
        text,
        startTime,
        endTime,
        x,
        y,
        scale,
        rotation,
        fontFamily,
        fontSize,
        color,
        isBold,
        isItalic,
        backgroundColor,
        backgroundOpacity,
        alignment,
      ];
}
