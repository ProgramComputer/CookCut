import 'dart:io';
import 'dart:convert';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import '../models/video_overlay_model.dart';
import '../repositories/video_overlay_repository_impl.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../../domain/entities/text_overlay.dart';
import '../../domain/entities/timer_overlay.dart';
import '../../domain/entities/background_music.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'ffmpeg_service.dart';

class VideoExportService {
  final VideoOverlayRepositoryImpl overlayRepository;
  final FFmpegService _ffmpegService;
  final FirebaseFirestore _firestore;

  VideoExportService({
    required this.overlayRepository,
  })  : _ffmpegService = FFmpegService(),
        _firestore = FirebaseFirestore.instance;

  Future<BackgroundMusic?> _getProjectBackgroundMusic(String projectId) async {
    final musicDoc = await _firestore
        .collection('projects')
        .doc(projectId)
        .collection('background_music')
        .get();

    if (musicDoc.docs.isEmpty) return null;

    // Get the first background music (assuming one per project for now)
    final data = musicDoc.docs.first.data();
    data['id'] = musicDoc.docs.first.id;
    return BackgroundMusic.fromJson(data);
  }

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

      // Get background music if exists
      final backgroundMusic = await _getProjectBackgroundMusic(projectId);

      // Process video with FFmpeg
      final result = await _ffmpegService.exportVideoWithOverlays(
        videoUrl: inputVideoPath,
        textOverlays: textOverlays,
        timerOverlays: timerOverlays,
        recipeOverlays: [],
        aspectRatio: aspectRatio,
        projectId: projectId,
        backgroundMusic: backgroundMusic,
      );

      return result['url'];
    } catch (e) {
      print('Error in video export service: $e');
      rethrow;
    }
  }
}
