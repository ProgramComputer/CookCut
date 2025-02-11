import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:video_player/video_player.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';
import 'package:video_thumbnail/video_thumbnail.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import '../../domain/entities/video_quality.dart';
import '../../domain/entities/video_processing_config.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'ffmpeg_service.dart';

enum ProcessingType { generateThumbnail, compressVideo, transcodeVideo }

class ProcessingTask {
  final ProcessingType type;
  final String inputPath;
  final Completer<bool> completer;
  final VideoProcessingConfig? config;
  final StreamController<double>? progressController;

  ProcessingTask({
    required this.type,
    required this.inputPath,
    required this.completer,
    this.config,
    this.progressController,
  });
}

class MediaProcessingService {
  final FirebaseAuth _auth;
  final SupabaseClient _supabase;
  final FFmpegService _ffmpegService;

  MediaProcessingService({
    FirebaseAuth? auth,
    SupabaseClient? supabase,
  })  : _auth = auth ?? FirebaseAuth.instance,
        _supabase = supabase ?? Supabase.instance.client,
        _ffmpegService = FFmpegService();

  Future<String?> generateThumbnail(String videoPath,
      {required String projectId}) async {
    try {
      final file = File(videoPath);
      if (!await file.exists()) {
        throw Exception('Video file not found: $videoPath');
      }

      // Generate thumbnail using video_thumbnail package
      final thumbnailPath = await VideoThumbnail.thumbnailFile(
        video: videoPath,
        thumbnailPath: (await getTemporaryDirectory()).path,
        imageFormat: ImageFormat.JPEG,
        quality: 75,
      );

      if (thumbnailPath == null) {
        throw Exception('Failed to generate thumbnail');
      }

      // Upload thumbnail to Supabase
      final fileName = '${path.basenameWithoutExtension(videoPath)}_thumb.jpg';
      final storagePath = 'projects/$projectId/media/thumbnails/$fileName';

      await _supabase.storage.from('cookcut-media').upload(
            storagePath,
            File(thumbnailPath),
            fileOptions: FileOptions(
              contentType: 'image/jpeg',
              upsert: true,
            ),
          );

      return _supabase.storage.from('cookcut-media').getPublicUrl(storagePath);
    } catch (e) {
      print('Error generating thumbnail: $e');
      return null;
    }
  }

  Future<String?> compressVideo(String videoPath, VideoQuality quality,
      {required String projectId}) async {
    try {
      // Build FFmpeg command for compression
      final command = _buildCompressionCommand(quality);

      final result = await _ffmpegService.exportVideoWithOverlays(
        videoUrl: videoPath,
        textOverlays: [],
        timerOverlays: [],
        recipeOverlays: [],
        aspectRatio: 16 / 9, // Default aspect ratio
        projectId: projectId,
      );

      return result['url'];
    } catch (e) {
      print('Error compressing video: $e');
      return null;
    }
  }

  String _buildCompressionCommand(VideoQuality quality) {
    switch (quality) {
      case VideoQuality.low:
        return '-c:v libx264 -crf 28 -preset medium -c:a aac -b:a 128k';
      case VideoQuality.medium:
        return '-c:v libx264 -crf 23 -preset medium -c:a aac -b:a 192k';
      case VideoQuality.high:
        return '-c:v libx264 -crf 18 -preset medium -c:a aac -b:a 256k';
      default:
        return '-c:v libx264 -crf 23 -preset medium -c:a aac -b:a 192k';
    }
  }
}
