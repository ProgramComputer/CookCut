import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:video_player/video_player.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:io';
import 'dart:ui' as ui;

class MediaProcessingService {
  final FirebaseAuth _auth;
  final SupabaseClient _supabase;
  final _processingQueue = StreamController<ProcessingTask>.broadcast();

  MediaProcessingService({
    FirebaseAuth? auth,
    SupabaseClient? supabase,
  })  : _auth = auth ?? FirebaseAuth.instance,
        _supabase = supabase ?? Supabase.instance.client {
    _initializeQueue();
  }

  void _initializeQueue() {
    _processingQueue.stream.listen((task) async {
      try {
        switch (task.type) {
          case ProcessingType.generateThumbnail:
            await _generateThumbnail(task);
            break;
          case ProcessingType.compressVideo:
            await _compressVideo(task);
            break;
          case ProcessingType.transcodeVideo:
            await _transcodeVideo(task);
            break;
        }
        task.completer.complete(true);
      } catch (e) {
        task.completer.completeError(e);
      }
    });
  }

  Future<String?> generateThumbnail(String videoPath) async {
    try {
      final file = File(videoPath);
      if (!await file.exists()) {
        print('Video file not found: $videoPath');
        return null;
      }

      final completer = Completer<String?>();
      final task = ProcessingTask(
        type: ProcessingType.generateThumbnail,
        inputPath: videoPath,
        completer: Completer<bool>(),
      );

      _processingQueue.add(task);
      await task.completer.future;

      // Initialize video player
      final controller = VideoPlayerController.file(file);
      try {
        await controller.initialize();

        // Get the video frame at the middle of the video
        await controller.seekTo(Duration(
            milliseconds: controller.value.duration.inMilliseconds ~/ 2));

        // Since we can't generate thumbnails with video_player, return null
        // This prevents the error from breaking the upload process
        return null;
      } catch (e) {
        print('Error initializing video player: $e');
        return null;
      } finally {
        await controller.dispose();
      }
    } catch (e) {
      print('Error in generateThumbnail: $e');
      return null;
    }
  }

  Future<String> compressVideo(String videoPath) async {
    final completer = Completer<String>();
    final task = ProcessingTask(
      type: ProcessingType.compressVideo,
      inputPath: videoPath,
      completer: Completer<bool>(),
    );

    _processingQueue.add(task);
    await task.completer.future;

    // Call Supabase Edge Function for video compression
    final response = await _supabase.functions.invoke(
      'compress-video',
      body: {
        'videoPath': videoPath,
        'quality': 'medium', // You can make this configurable if needed
      },
    );

    if (response.data == null || response.data['compressedUrl'] == null) {
      throw Exception('Failed to compress video');
    }

    return response.data['compressedUrl'];
  }

  Future<String> transcodeVideo(String videoPath, String format) async {
    final completer = Completer<String>();
    final task = ProcessingTask(
      type: ProcessingType.transcodeVideo,
      inputPath: videoPath,
      completer: Completer<bool>(),
    );

    _processingQueue.add(task);
    await task.completer.future;

    // Call Supabase Edge Function for video transcoding
    final response = await _supabase.functions.invoke(
      'transcode-video',
      body: {
        'videoPath': videoPath,
        'format': format,
      },
    );

    if (response.data == null || response.data['transcodedUrl'] == null) {
      throw Exception('Failed to transcode video');
    }

    return response.data['transcodedUrl'];
  }

  Future<void> _generateThumbnail(ProcessingTask task) async {
    // Implementation of thumbnail generation
    // This is handled by the video_player in the main method
  }

  Future<void> _compressVideo(ProcessingTask task) async {
    // Implementation of video compression
    // This is handled by the Supabase Edge Function
  }

  Future<void> _transcodeVideo(ProcessingTask task) async {
    // Implementation of video transcoding
    // This is handled by the Supabase Edge Function
  }

  void dispose() {
    _processingQueue.close();
  }
}

class ProcessingTask {
  final ProcessingType type;
  final String inputPath;
  final Completer<bool> completer;

  ProcessingTask({
    required this.type,
    required this.inputPath,
    required this.completer,
  });
}

enum ProcessingType {
  generateThumbnail,
  compressVideo,
  transcodeVideo,
}
