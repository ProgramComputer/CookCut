import 'dart:io';
import 'dart:convert';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import '../models/video_overlay_model.dart';
import '../repositories/video_overlay_repository_impl.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../../domain/entities/text_overlay.dart';
import '../../domain/entities/timer_overlay.dart';
import 'ffmpeg_service.dart';

class VideoExportService {
  final VideoOverlayRepositoryImpl overlayRepository;
  final FFmpegService _ffmpegService;

  VideoExportService({
    required this.overlayRepository,
  }) : _ffmpegService = FFmpegService();

  Future<String> exportVideoWithOverlays({
    required String projectId,
    required String inputVideoPath,
    required double aspectRatio,
  }) async {
    try {
      // Get all overlays
      final overlays = await overlayRepository.getProjectOverlays(projectId);

      // Split overlays into text and timer
      final textOverlays = overlays
          .where((o) => o.type == 'text')
          .map((o) => o.toTextOverlay())
          .toList();

      final timerOverlays = overlays
          .where((o) => o.type == 'timer')
          .map((o) => o.toTimerOverlay())
          .toList();

      // Process video with FFmpeg
      final result = await _ffmpegService.exportVideoWithOverlays(
        videoUrl: inputVideoPath,
        textOverlays: textOverlays,
        timerOverlays: timerOverlays,
        recipeOverlays: [],
        aspectRatio: aspectRatio,
        projectId: projectId,
      );

      return result['url'];
    } catch (e) {
      print('Error in video export service: $e');
      rethrow;
    }
  }
}
