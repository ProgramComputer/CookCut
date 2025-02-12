import '../entities/text_overlay.dart';
import '../entities/timer_overlay.dart';
import '../entities/video_overlay_model.dart';

abstract class VideoOverlayRepository {
  Stream<List<VideoOverlayModel>> watchProjectOverlays(String projectId);
  Future<List<VideoOverlayModel>> getProjectOverlays(String projectId);
  Future<void> addTextOverlay(String projectId, TextOverlay overlay);
  Future<void> addTimerOverlay(String projectId, TimerOverlay overlay);
  Future<void> updateTextOverlay(String projectId, TextOverlay overlay);
  Future<void> updateTimerOverlay(String projectId, TimerOverlay overlay);
  Future<void> deleteOverlay(String overlayId);
}
