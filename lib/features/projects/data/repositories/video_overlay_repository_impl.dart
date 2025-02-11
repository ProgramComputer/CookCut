import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../domain/entities/text_overlay.dart';
import '../../domain/entities/timer_overlay.dart';
import '../models/video_overlay_model.dart';

class VideoOverlayRepositoryImpl {
  final FirebaseFirestore firestore;
  final FirebaseAuth auth;

  VideoOverlayRepositoryImpl({
    required this.firestore,
    required this.auth,
  });

  CollectionReference<Map<String, dynamic>> get _overlaysCollection =>
      firestore.collection('video_overlays');

  Stream<List<VideoOverlayModel>> watchProjectOverlays(String projectId) {
    return _overlaysCollection
        .where('project_id', isEqualTo: projectId)
        .orderBy('created_at')
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => VideoOverlayModel.fromFirestore(doc))
            .toList());
  }

  Future<void> addTextOverlay(String projectId, TextOverlay overlay) async {
    final model = VideoOverlayModel.fromTextOverlay(projectId, overlay);
    await _overlaysCollection.doc(overlay.id).set(model.toFirestore());
  }

  Future<void> addTimerOverlay(String projectId, TimerOverlay overlay) async {
    final model = VideoOverlayModel.fromTimerOverlay(projectId, overlay);
    await _overlaysCollection.doc(overlay.id).set(model.toFirestore());
  }

  Future<void> updateTextOverlay(String projectId, TextOverlay overlay) async {
    final model = VideoOverlayModel.fromTextOverlay(projectId, overlay);
    await _overlaysCollection.doc(overlay.id).update(model.toFirestore());
  }

  Future<void> updateTimerOverlay(
      String projectId, TimerOverlay overlay) async {
    final model = VideoOverlayModel.fromTimerOverlay(projectId, overlay);
    await _overlaysCollection.doc(overlay.id).update(model.toFirestore());
  }

  Future<void> deleteOverlay(String overlayId) async {
    await _overlaysCollection.doc(overlayId).delete();
  }

  Future<List<VideoOverlayModel>> getProjectOverlays(String projectId) async {
    final snapshot = await _overlaysCollection
        .where('project_id', isEqualTo: projectId)
        .orderBy('created_at')
        .get();

    return snapshot.docs
        .map((doc) => VideoOverlayModel.fromFirestore(doc))
        .toList();
  }
}
