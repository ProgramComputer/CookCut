import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http_parser/http_parser.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:typed_data';
import 'package:path/path.dart' as path;
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/entities/text_overlay.dart';
import '../../domain/entities/timer_overlay.dart';
import 'dart:async';
import '../../domain/entities/recipe_overlay.dart';
import '../../domain/entities/background_music.dart';

class FFmpegService {
  final String _baseUrl;
  final SupabaseClient _supabase;
  final FirebaseFirestore _firestore;
  final String _apiKey;

  FFmpegService({String? baseUrl})
      : _baseUrl = _formatUrl(baseUrl ?? dotenv.env['AWS_EC2_FFMPEG'] ?? ''),
        _supabase = Supabase.instance.client,
        _firestore = FirebaseFirestore.instance,
        _apiKey = dotenv.env['FFMPEG_API_KEY'] ?? '';

  // Make baseUrl accessible
  String get baseUrl => _baseUrl;

  // Helper method to ensure URL has protocol
  static String _formatUrl(String url) {
    if (url.isEmpty) return '';
    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      return 'http://$url';
    }
    return url.trim();
  }

  Map<String, String> get headers => {
        'Content-Type': 'application/json',
        'Connection': 'keep-alive',
        'Accept': '*/*',
        'x-api-key': _apiKey,
      };

  Future<Map<String, dynamic>> trimVideo({
    required String videoUrl,
    required String projectId,
    required Duration startTime,
    required Duration endTime,
    required int position,
    required int layer,
  }) async {
    try {
      if (_apiKey.isEmpty) {
        throw Exception('FFmpeg API key not configured');
      }

      // Construct FFmpeg command for trimming
      final command = '''
        ffmpeg -i input.mp4 -ss ${startTime.inMilliseconds / 1000.0} -t ${(endTime - startTime).inMilliseconds / 1000.0} 
        -c:v libx264 -c:a aac -avoid_negative_ts make_zero output.mp4
      '''
          .replaceAll('\n', ' ')
          .trim();

      // Use _processVideoUrl which properly handles the /process-url endpoint
      return await _processVideoUrl(videoUrl, command, projectId);
    } catch (e) {
      print('Error in trimVideo: $e');
      throw Exception('Failed to trim video: $e');
    }
  }

  Future<Map<String, dynamic>> checkJobStatus(String jobId) async {
    try {
      print('Checking status for job $jobId at $baseUrl');

      final response = await http.get(
        Uri.parse('$baseUrl/progress/$jobId'),
        headers: {
          'x-api-key': _apiKey,
          'Content-Type': 'application/json',
        },
      );

      print('Status response: ${response.statusCode} - ${response.body}');

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      } else {
        throw Exception('Failed to check job status: ${response.body}');
      }
    } catch (e) {
      print('❌ Error checking job status: $e');
      throw Exception('Failed to check job status: $e');
    }
  }

  Future<void> _createClip({
    required String projectId,
    required String originalFileUrl,
    required String processedFileUrl,
    required double startTime,
    required double endTime,
    required int position,
    required int layer,
  }) async {
    await _firestore
        .collection('projects')
        .doc(projectId)
        .collection('clips')
        .add({
      'originalFileUrl': originalFileUrl,
      'processedFileUrl': processedFileUrl,
      'startTime': startTime,
      'endTime': endTime,
      'position': position,
      'layer': layer,
      'status': 'ready',
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'createdBy': _supabase.auth.currentUser?.id,
    });
  }

  Future<Map<String, dynamic>> exportVideoWithOverlays({
    required String videoUrl,
    required List<TextOverlay> textOverlays,
    required List<TimerOverlay> timerOverlays,
    required List<RecipeOverlay> recipeOverlays,
    required double aspectRatio,
    required String projectId,
    BackgroundMusic? backgroundMusic,
  }) async {
    try {
      print('Starting video export with overlays');

      // Build complex FFmpeg command with overlays and background music
      final filterComplex = _buildFilterComplex(
        textOverlays,
        timerOverlays,
        recipeOverlays,
        backgroundMusic,
      );

      final command = '''
        ffmpeg -i input.mp4 ${backgroundMusic != null ? '-i "${backgroundMusic.url}"' : ''} 
        -filter_complex "$filterComplex" 
        -c:v libx264 -preset medium -crf 23 
        -c:a aac -b:a 192k 
        -movflags +faststart output.mp4
      '''
          .replaceAll('\n', ' ')
          .trim();

      return await _processVideoUrl(videoUrl, command, projectId);
    } catch (e, stackTrace) {
      print('Error in FFmpeg service: $e');
      print('Stack trace: $stackTrace');
      rethrow;
    }
  }

  String _buildFilterComplex(
    List<TextOverlay> textOverlays,
    List<TimerOverlay> timerOverlays,
    List<RecipeOverlay> recipeOverlays,
    BackgroundMusic? backgroundMusic,
  ) {
    final List<String> filters = [];
    var currentInput = '[0:v]';
    var currentOutput = '[v0]';
    var filterIndex = 1;

    // Add background music if provided
    if (backgroundMusic != null) {
      // Mix original audio with background music
      filters.add(
          '[0:a][1:a]amix=inputs=2:duration=first:weights=${1 - backgroundMusic.volume} ${backgroundMusic.volume}[aout]');

      // Trim background music if needed
      if (backgroundMusic.startTime > 0 || backgroundMusic.endTime > 0) {
        filters.add(
            '[1:a]atrim=start=${backgroundMusic.startTime}:end=${backgroundMusic.endTime}[bgm]');
      }
    }

    // Process text overlays
    for (final overlay in textOverlays) {
      final fontColor = overlay.color.replaceAll('#', '0x');
      final boxColor = overlay.backgroundColor.replaceAll('#', '0x');
      final fontFile = overlay.fontFamily.toLowerCase() == 'arial'
          ? 'Arial'
          : overlay.fontFamily;

      final drawText = 'drawtext=text=\'${overlay.text}\':fontfile=$fontFile:'
          'fontsize=${overlay.fontSize}:fontcolor=$fontColor@${overlay.backgroundOpacity}:'
          'box=1:boxcolor=$boxColor@${overlay.backgroundOpacity}:'
          'x=(w-text_w)*${overlay.x}:y=(h-text_h)*${overlay.y}:'
          'enable=\'between(t,${overlay.startTime},${overlay.endTime})\'';

      filters.add('$currentInput$drawText$currentOutput');
      currentInput = currentOutput;
      currentOutput = '[v${filterIndex++}]';
    }

    // Process timer overlays
    for (final overlay in timerOverlays) {
      final fontColor = overlay.color.replaceAll('#', '0x');
      final boxColor = overlay.backgroundColor.replaceAll('#', '0x');
      final labelPrefix = overlay.label != null ? '${overlay.label}: ' : '';
      final timeFormat = overlay.showMilliseconds ? '%M\\:%S.%3d' : '%M\\:%S';

      final drawText = 'drawtext=text=\'$labelPrefix%{pts\\:$timeFormat}\':'
          'fontsize=${30 * overlay.scale}:fontcolor=$fontColor@${overlay.backgroundOpacity}:'
          'box=1:boxcolor=$boxColor@${overlay.backgroundOpacity}:'
          'x=(w-text_w)*${overlay.x}:y=(h-text_h)*${overlay.y}:'
          'enable=\'between(t,${overlay.startTime},${overlay.endTime})\'';

      filters.add('$currentInput$drawText$currentOutput');
      currentInput = currentOutput;
      currentOutput = '[v${filterIndex++}]';
    }

    // Process recipe overlays
    for (final overlay in recipeOverlays) {
      final fontColor = overlay.color.replaceAll('#', '0x');
      final boxColor = overlay.backgroundColor.replaceAll('#', '0x');
      final fontFile = overlay.fontFamily.toLowerCase() == 'arial'
          ? 'Arial'
          : overlay.fontFamily;

      // Build recipe text with ingredient and quantity if available
      final recipeText = [
        if (overlay.ingredient != null && overlay.quantity != null)
          '${overlay.quantity} ${overlay.ingredient}:',
        overlay.instruction,
      ].join('\\n');

      // Add icon if enabled
      final iconText = overlay.showIcon && overlay.iconType != null
          ? '[${overlay.iconType}] '
          : '';

      final drawText =
          'drawtext=text=\'$iconText$recipeText\':fontfile=$fontFile:'
          'fontsize=${overlay.fontSize}:fontcolor=$fontColor@${overlay.backgroundOpacity}:'
          'box=1:boxcolor=$boxColor@${overlay.backgroundOpacity}:'
          'x=(w-text_w)*${overlay.x}:y=(h-text_h)*${overlay.y}:'
          'enable=\'between(t,${overlay.startTime},${overlay.endTime})\':'
          'line_spacing=10'; // Add spacing between lines

      filters.add('$currentInput$drawText$currentOutput');
      currentInput = currentOutput;
      currentOutput = '[v${filterIndex++}]';
    }

    // If no overlays but has background music
    if (filters.isEmpty && backgroundMusic != null) {
      return '[0:a][1:a]amix=inputs=2:duration=first:weights=1 ${backgroundMusic.volume}[aout]';
    }

    // If no overlays and no background music
    if (filters.isEmpty) {
      return 'null';
    }

    return filters.join(';');
  }

  Future<Map<String, dynamic>> _processVideoUrl(
    String videoUrl,
    String command,
    String projectId,
  ) async {
    try {
      print('Processing video URL: $videoUrl');
      print('FFmpeg command: $command');
      print('Project ID: $projectId');

      if (_apiKey.isEmpty) {
        throw Exception('FFmpeg API key not configured');
      }

      final client = http.Client();
      try {
        // Increase initial request timeout
        final response = await client
            .post(
          Uri.parse('$_baseUrl/process-url'),
          headers: headers,
          body: jsonEncode({
            'videoUrl': videoUrl,
            'command': command,
            'projectId': projectId,
          }),
        )
            .timeout(
          const Duration(minutes: 1),
          onTimeout: () {
            print('Initial request timed out after 1 minute');
            client.close();
            throw TimeoutException('Initial request timed out after 1 minute');
          },
        );

        print('Initial response status code: ${response.statusCode}');
        print('Response headers: ${response.headers}');
        print('Response body: ${response.body}');

        if (response.statusCode == 401) {
          throw Exception('Unauthorized: Invalid API key');
        }

        if (response.statusCode != 200) {
          print(
              'Error response received: ${jsonDecode(response.body)['error']}');
          throw Exception(
              'Failed to process video: ${jsonDecode(response.body)['error']}');
        }

        final jsonResponse = jsonDecode(response.body);
        print('Parsed response: $jsonResponse');

        // Add retry logic for status checks
        int retryCount = 0;
        const maxRetries = 3;
        const retryDelay = Duration(seconds: 2);

        while (retryCount < maxRetries) {
          try {
            final status = await getExportProgress(jsonResponse['jobId']);
            if (status['status'] == 'failed') {
              throw Exception(status['error'] ?? 'Video processing failed');
            }
            if (status['status'] == 'complete') {
              return status;
            }
            await Future.delayed(retryDelay);
            retryCount++;
          } catch (e) {
            print('Error checking status (attempt ${retryCount + 1}): $e');
            if (retryCount >= maxRetries - 1) rethrow;
            await Future.delayed(retryDelay);
            retryCount++;
          }
        }

        return jsonResponse;
      } finally {
        client.close();
      }
    } catch (e, stack) {
      print('Error in _processVideoUrl: $e');
      print('Stack trace: $stack');

      // Improve error messages for common issues
      if (e.toString().contains('Connection closed')) {
        throw Exception(
            'Lost connection to server. Please check your internet connection and try again.');
      } else if (e is TimeoutException) {
        throw Exception(
            'Request timed out. The server might be busy, please try again.');
      }
      rethrow;
    }
  }

  Future<Map<String, dynamic>> getExportProgress(String jobId) async {
    try {
      print('Checking status for job $jobId at $_baseUrl');
      final client = http.Client();
      try {
        final response = await client
            .get(
          Uri.parse('$_baseUrl/progress/$jobId'),
          headers: headers,
        )
            .timeout(
          const Duration(seconds: 10),
          onTimeout: () {
            print('Status request timed out after 10 seconds');
            return http.Response(
              jsonEncode({
                'status': 'pending',
                'error': 'Status request timed out',
                'progress': 0.0
              }),
              408,
            );
          },
        );

        print('Status response: ${response.statusCode} - ${response.body}');

        if (response.statusCode == 401) {
          return {
            'status': 'failed',
            'error': 'Unauthorized: Invalid API key',
            'progress': 0.0
          };
        }

        if (response.statusCode != 200) {
          return {
            'status': 'pending',
            'error': 'Failed to get status: ${response.statusCode}',
            'progress': 0.0
          };
        }

        final status = jsonDecode(response.body);
        return status as Map<String, dynamic>;
      } finally {
        client.close();
      }
    } catch (e, stack) {
      print('Error getting export progress: $e');
      print('Stack trace: $stack');

      // Return a more informative status for connection issues
      if (e.toString().contains('Connection closed')) {
        return {
          'status': 'pending',
          'error': 'Connection interrupted. Retrying...',
          'progress': 0.0
        };
      }
      return {'status': 'pending', 'error': e.toString(), 'progress': 0.0};
    }
  }

  // Helper method to extract project ID from video URL
  String? _extractProjectId(String url) {
    // Example URL: https://...supabase.co/.../projects/A6Gv1Q2lVhaltK90wU1W/media/raw/cooking.mp4
    final match = RegExp(r'projects/([^/]+)/media').firstMatch(url);
    return match?.group(1);
  }
}
