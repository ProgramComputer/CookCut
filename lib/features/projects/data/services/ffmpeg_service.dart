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

      final response = await http.post(
        Uri.parse('$_baseUrl/trim'),
        headers: headers,
        body: jsonEncode({
          'videoUrl': videoUrl,
          'projectId': projectId,
          'startTime': startTime.inMilliseconds / 1000.0,
          'endTime': endTime.inMilliseconds / 1000.0,
          'position': position,
          'layer': layer,
        }),
      );

      if (response.statusCode == 401) {
        throw Exception('Unauthorized: Invalid API key');
      }

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      } else {
        throw Exception('Failed to trim video: ${response.body}');
      }
    } catch (e) {
      print('Error in trimVideo: $e');
      throw Exception('Failed to trim video: $e');
    }
  }

  Future<Map<String, dynamic>> checkJobStatus(String jobId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/progress/$jobId'),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      } else {
        throw Exception('Failed to check job status: ${response.body}');
      }
    } catch (e) {
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
  }) async {
    try {
      print('Starting video export with overlays');

      // Build complex FFmpeg command with overlays
      final filterComplex =
          _buildFilterComplex(textOverlays, timerOverlays, recipeOverlays);

      final command = '''
        ffmpeg -i input.mp4 -filter_complex "$filterComplex" 
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
  ) {
    final List<String> filters = [];
    var currentInput = '[0:v]';
    var currentOutput = '[v0]';
    var filterIndex = 1;

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

    // If no overlays, pass through
    if (filters.isEmpty) {
      return 'null';
    }

    return filters.join(';');
  }

  Future<Map<String, dynamic>> _processVideoUrl(
      String videoUrl, String command, String projectId) async {
    try {
      print('Processing video URL: $videoUrl');
      print('FFmpeg command: $command');
      print('Project ID: $projectId');

      if (_apiKey.isEmpty) {
        throw Exception('FFmpeg API key not configured');
      }

      final client = http.Client();
      try {
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
          const Duration(seconds: 30),
          onTimeout: () {
            print('Initial request timed out after 30 seconds');
            client.close();
            throw TimeoutException(
                'Initial request timed out after 30 seconds');
          },
        );

        print('Initial response status code: ${response.statusCode}');
        print('Response headers: ${response.headers}');
        print('Response body: ${response.body}');

        final jsonResponse = jsonDecode(response.body);
        print('Parsed response: $jsonResponse');

        if (response.statusCode == 401) {
          throw Exception('Unauthorized: Invalid API key');
        }

        if (response.statusCode != 200) {
          print('Error response received: ${jsonResponse['error']}');
          throw Exception('Failed to process video: ${jsonResponse['error']}');
        }

        return jsonResponse;
      } finally {
        client.close();
      }
    } catch (e, stack) {
      print('Error in _processVideoUrl: $e');
      print('Stack trace: $stack');
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
          Uri.parse('$_baseUrl/status/$jobId'),
          headers: headers,
        )
            .timeout(
          const Duration(seconds: 5),
          onTimeout: () {
            print('Status request timed out after 5 seconds');
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
