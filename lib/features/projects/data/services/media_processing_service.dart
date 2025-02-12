import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
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
import 'package:flutter/material.dart';
import 'package:cached_video_player_plus/cached_video_player_plus.dart';

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
  final String baseUrl;
  final http.Client _client;
  final SupabaseClient supabase;

  MediaProcessingService({
    String? baseUrl,
    http.Client? client,
    required this.supabase,
  })  : baseUrl = baseUrl ??
            dotenv.env['MEDIA_PROCESSING_URL'] ??
            'http://localhost:3000',
        _client = client ?? http.Client();

  Future<Map<String, dynamic>> processVideo({
    required String videoUrl,
    required String projectId,
    required int position,
    int layer = 0,
  }) async {
    try {
      // Initialize video player to get metadata
      final controller = CachedVideoPlayerPlusController.networkUrl(
        Uri.parse(videoUrl),
      );
      await controller.initialize();

      final duration = controller.value.duration;
      final size = controller.value.size;

      // Clean up controller
      await controller.dispose();

      // Make API request to process video
      final response = await _client.post(
        Uri.parse('$baseUrl/process'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'videoUrl': videoUrl,
          'projectId': projectId,
          'position': position,
          'layer': layer,
          'duration': duration.inMilliseconds,
          'width': size.width,
          'height': size.height,
        }),
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to process video: ${response.statusCode}');
      }

      return jsonDecode(response.body) as Map<String, dynamic>;
    } catch (e) {
      throw Exception('Error processing video: ${e.toString()}');
    }
  }

  Future<String?> generateThumbnail(String videoPath,
      {required String projectId}) async {
    try {
      final file = File(videoPath);
      if (!await file.exists()) {
        throw Exception('Video file not found: $videoPath');
      }

      // Generate thumbnail using video_thumbnail package with optimized settings
      final thumbnailPath = await VideoThumbnail.thumbnailFile(
        video: videoPath,
        thumbnailPath: (await getTemporaryDirectory()).path,
        imageFormat: ImageFormat.JPEG,
        maxHeight: 720, // Limit thumbnail height
        quality: 85, // Good quality but not too large
      );

      if (thumbnailPath == null) {
        throw Exception('Failed to generate thumbnail');
      }

      // Upload thumbnail directly to Supabase storage
      final fileName =
          '${DateTime.now().millisecondsSinceEpoch}_${path.basename(videoPath)}_thumb.jpg';
      final storagePath = 'media/$projectId/thumbnails/$fileName';

      await supabase.storage.from('cookcut-media').upload(
            storagePath,
            File(thumbnailPath),
            fileOptions: const FileOptions(
              contentType: 'image/jpeg',
              upsert: true,
            ),
          );

      // Get the public URL for the thumbnail
      final thumbnailUrl =
          supabase.storage.from('cookcut-media').getPublicUrl(storagePath);

      // Clean up the temporary file
      try {
        await File(thumbnailPath).delete();
      } catch (e) {
        print('Warning: Failed to delete temporary thumbnail file: $e');
      }

      return thumbnailUrl;
    } catch (e) {
      print('Error generating thumbnail: $e');
      return null;
    }
  }

  void dispose() {
    _client.close();
  }
}
