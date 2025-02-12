import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../domain/entities/text_overlay.dart';
import '../../domain/entities/timer_overlay.dart';
import '../../domain/entities/video_overlay_model.dart';
import '../../domain/repositories/video_overlay_repository.dart';
import '../models/video_overlay_model.dart' as data_model;
import 'package:flutter/rendering.dart';

class VideoOverlayRepositoryImpl implements VideoOverlayRepository {
  final FirebaseFirestore firestore;
  final FirebaseAuth auth;

  VideoOverlayRepositoryImpl({
    required this.firestore,
    required this.auth,
  });

  CollectionReference<Map<String, dynamic>> get _overlaysCollection =>
      firestore.collection('video_overlays');

  @override
  Stream<List<VideoOverlayModel>> watchProjectOverlays(String projectId) {
    return _overlaysCollection
        .where('project_id', isEqualTo: projectId)
        .orderBy('created_at')
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => data_model.VideoOverlayModel.fromFirestore(doc))
            .map((model) => _convertToEntity(model))
            .toList());
  }

  @override
  Future<List<VideoOverlayModel>> getProjectOverlays(String projectId) async {
    final snapshot = await _overlaysCollection
        .where('project_id', isEqualTo: projectId)
        .orderBy('created_at')
        .get();

    return snapshot.docs
        .map((doc) => data_model.VideoOverlayModel.fromFirestore(doc))
        .map((model) => _convertToEntity(model))
        .toList();
  }

  @override
  Future<void> addTextOverlay(String projectId, TextOverlay overlay) async {
    final model =
        data_model.VideoOverlayModel.fromTextOverlay(projectId, overlay);
    await _overlaysCollection.doc(overlay.id).set(model.toFirestore());
  }

  @override
  Future<void> addTimerOverlay(String projectId, TimerOverlay overlay) async {
    final model =
        data_model.VideoOverlayModel.fromTimerOverlay(projectId, overlay);
    await _overlaysCollection.doc(overlay.id).set(model.toFirestore());
  }

  @override
  Future<void> updateTextOverlay(String projectId, TextOverlay overlay) async {
    final model =
        data_model.VideoOverlayModel.fromTextOverlay(projectId, overlay);
    await _overlaysCollection.doc(overlay.id).update(model.toFirestore());
  }

  @override
  Future<void> updateTimerOverlay(
      String projectId, TimerOverlay overlay) async {
    final model =
        data_model.VideoOverlayModel.fromTimerOverlay(projectId, overlay);
    await _overlaysCollection.doc(overlay.id).update(model.toFirestore());
  }

  @override
  Future<void> deleteOverlay(String overlayId) async {
    await _overlaysCollection.doc(overlayId).delete();
  }

  VideoOverlayModel _convertToEntity(data_model.VideoOverlayModel model) {
    if (model.type == 'text') {
      return TextOverlayModel(
        id: model.id,
        text: model.data['text'] as String,
        position: Offset(model.x, model.y),
        color: model.data['color'] as String,
        fontSize: (model.data['font_size'] as num).toDouble(),
        startTime: model.startTime,
        endTime: model.endTime,
      );
    } else {
      return TimerOverlayModel(
        id: model.id,
        durationSeconds: model.data['duration_seconds'] as int,
        position: Offset(model.x, model.y),
        color: model.data['color'] as String,
        fontSize: (model.data['font_size'] as num).toDouble(),
        startTime: model.startTime,
      );
    }
  }
}
