import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/entities/text_overlay.dart';
import '../../domain/entities/timer_overlay.dart';

class VideoOverlayModel {
  final String id;
  final String projectId;
  final String type; // 'text' or 'timer'
  final Map<String, dynamic> data;
  final double startTime;
  final double endTime;
  final double x;
  final double y;
  final DateTime createdAt;
  final DateTime updatedAt;

  VideoOverlayModel({
    required this.id,
    required this.projectId,
    required this.type,
    required this.data,
    required this.startTime,
    required this.endTime,
    required this.x,
    required this.y,
    required this.createdAt,
    required this.updatedAt,
  });

  factory VideoOverlayModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return VideoOverlayModel(
      id: doc.id,
      projectId: data['project_id'] as String,
      type: data['type'] as String,
      data: data['data'] as Map<String, dynamic>,
      startTime: (data['start_time'] as num).toDouble(),
      endTime: (data['end_time'] as num).toDouble(),
      x: (data['x'] as num).toDouble(),
      y: (data['y'] as num).toDouble(),
      createdAt: (data['created_at'] as Timestamp).toDate(),
      updatedAt: (data['updated_at'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'project_id': projectId,
      'type': type,
      'data': data,
      'start_time': startTime,
      'end_time': endTime,
      'x': x,
      'y': y,
      'created_at': Timestamp.fromDate(createdAt),
      'updated_at': Timestamp.fromDate(updatedAt),
    };
  }

  factory VideoOverlayModel.fromTextOverlay(
    String projectId,
    TextOverlay overlay,
  ) {
    return VideoOverlayModel(
      id: overlay.id,
      projectId: projectId,
      type: 'text',
      data: {
        'text': overlay.text,
        'font_family': overlay.fontFamily,
        'font_size': overlay.fontSize,
        'color': overlay.color,
        'is_bold': overlay.isBold,
        'is_italic': overlay.isItalic,
        'background_color': overlay.backgroundColor,
        'background_opacity': overlay.backgroundOpacity,
        'alignment': overlay.alignment,
        'scale': overlay.scale,
        'rotation': overlay.rotation,
      },
      startTime: overlay.startTime,
      endTime: overlay.endTime,
      x: overlay.x,
      y: overlay.y,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  factory VideoOverlayModel.fromTimerOverlay(
    String projectId,
    TimerOverlay overlay,
  ) {
    return VideoOverlayModel(
      id: overlay.id,
      projectId: projectId,
      type: 'timer',
      data: {
        'duration_seconds': overlay.durationSeconds,
        'style': overlay.style,
        'color': overlay.color,
        'show_milliseconds': overlay.showMilliseconds,
        'background_color': overlay.backgroundColor,
        'background_opacity': overlay.backgroundOpacity,
        'alignment': overlay.alignment,
        'label': overlay.label,
        'scale': overlay.scale,
      },
      startTime: overlay.startTime,
      endTime: overlay.startTime + overlay.durationSeconds,
      x: overlay.x,
      y: overlay.y,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  TextOverlay toTextOverlay() {
    if (type != 'text') throw Exception('Not a text overlay');
    return TextOverlay(
      id: id,
      text: data['text'] as String,
      startTime: startTime,
      endTime: endTime,
      x: x,
      y: y,
      fontFamily: data['font_family'] as String,
      fontSize: (data['font_size'] as num).toDouble(),
      color: data['color'] as String,
      isBold: data['is_bold'] as bool,
      isItalic: data['is_italic'] as bool,
      backgroundColor: data['background_color'] as String,
      backgroundOpacity: (data['background_opacity'] as num).toDouble(),
      alignment: data['alignment'] as String,
      scale: (data['scale'] as num).toDouble(),
      rotation: (data['rotation'] as num).toDouble(),
    );
  }

  TimerOverlay toTimerOverlay() {
    if (type != 'timer') throw Exception('Not a timer overlay');
    return TimerOverlay(
      id: id,
      durationSeconds: (data['duration_seconds'] as num).toInt(),
      startTime: startTime,
      x: x,
      y: y,
      style: data['style'] as String,
      color: data['color'] as String,
      showMilliseconds: data['show_milliseconds'] as bool,
      backgroundColor: data['background_color'] as String,
      backgroundOpacity: (data['background_opacity'] as num).toDouble(),
      alignment: data['alignment'] as String,
      label: data['label'] as String?,
      scale: (data['scale'] as num).toDouble(),
    );
  }
}
