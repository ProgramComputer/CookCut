import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'dart:developer' as developer;

class ReplicateService {
  final String _baseUrl = 'https://api.replicate.com/v1';
  late final String _apiKey;

  // Negative prompts to ensure high-quality cooking videos
  static const String _negativePrompt = '''
blurry, low quality, distorted, ugly, poorly made, 
unsafe food handling, unsanitary conditions, dirty workspace,
text overlays, watermarks, logos, poor lighting, shaky camera,
unappetizing presentation, messy preparation, non-food content,
inappropriate content, dangerous practices, raw meat contamination,
expired ingredients, mold, spoiled food, insects, pests,
dirty hands, unwashed vegetables, cross-contamination
''';

  ReplicateService() {
    developer.log(
      'Initializing ReplicateService',
      name: 'ReplicateService',
    );
    _apiKey = dotenv.env['REPLICATE_API_KEY'] ?? '';
    if (_apiKey.isEmpty) {
      developer.log(
        'REPLICATE_API_KEY not found',
        name: 'ReplicateService',
        error: 'API key is empty',
      );
      throw Exception('REPLICATE_API_KEY not found in environment variables');
    }
    developer.log(
      'ReplicateService initialized successfully',
      name: 'ReplicateService',
      error: {'apiKeyLength': _apiKey.length},
    );
  }

  Future<Map<String, dynamic>> generateStockVideo({
    required String prompt,
    required int durationSeconds,
  }) async {
    developer.log(
      'generateStockVideo called',
      name: 'ReplicateService',
      error: {
        'prompt': prompt,
        'duration': durationSeconds,
      },
    );

    developer.log(
      'Starting video generation request',
      name: 'ReplicateService',
      error: {
        'prompt': prompt,
        'duration': durationSeconds,
      },
    );

    // Validate duration is either 5 or 10 seconds
    if (durationSeconds != 5 && durationSeconds != 10) {
      const error =
          'Video duration must be either 5 or 10 seconds for Kling v1.6.';
      developer.log(
        'Duration validation failed',
        name: 'ReplicateService',
        error: error,
      );
      throw Exception(error);
    }

    // Validate prompt is not empty
    if (prompt.trim().isEmpty) {
      const error = 'Prompt cannot be empty';
      developer.log(
        'Prompt validation failed',
        name: 'ReplicateService',
        error: error,
      );
      throw Exception(error);
    }

    try {
      final requestUrl =
          '$_baseUrl/models/kwaivgi/kling-v1.6-standard/predictions';
      final requestBody = jsonEncode({
        'input': {
          'prompt': prompt,
          'negative_prompt': _negativePrompt,
          'duration': durationSeconds,
          'cfg_scale': 0.5,
          'aspect_ratio': '16:9',
        },
      });

      developer.log(
        'Sending API request',
        name: 'ReplicateService',
        error: {
          'url': requestUrl,
          'body': requestBody,
        },
      );

      final response = await http.post(
        Uri.parse(requestUrl),
        headers: {
          'Authorization': 'Token $_apiKey',
          'Content-Type': 'application/json',
        },
        body: requestBody,
      );

      developer.log(
        'Received API response',
        name: 'ReplicateService',
        error: {
          'statusCode': response.statusCode,
          'headers': response.headers,
          'body': response.body,
        },
      );

      if (response.statusCode == 429) {
        final error = jsonDecode(response.body);
        final errorMsg =
            'Rate limit exceeded: ${error['detail']}. Please try again later.';
        developer.log(
          'Rate limit exceeded',
          name: 'ReplicateService',
          error: {
            'detail': error['detail'],
            'headers': response.headers,
          },
        );
        throw Exception(errorMsg);
      }

      if (response.statusCode != 201) {
        final error = jsonDecode(response.body);
        final errorMsg =
            'Failed to start video generation: ${error['detail'] ?? response.body}';
        developer.log(
          'API request failed',
          name: 'ReplicateService',
          error: {
            'statusCode': response.statusCode,
            'error': error,
            'headers': response.headers,
          },
        );
        throw Exception(errorMsg);
      }

      final prediction = jsonDecode(response.body);
      developer.log(
        'Successfully started video generation',
        name: 'ReplicateService',
        error: {
          'predictionId': prediction['id'],
          'status': prediction['status'],
          'urls': prediction['urls'],
          'headers': response.headers,
        },
      );
      return prediction;
    } catch (e, stackTrace) {
      developer.log(
        'Error in video generation',
        name: 'ReplicateService',
        error: e,
        stackTrace: stackTrace,
      );
      throw Exception('Error generating video: $e');
    }
  }

  Future<Map<String, dynamic>> checkGenerationStatus(
      String predictionId) async {
    developer.log(
      'Checking generation status',
      name: 'ReplicateService',
      error: {'predictionId': predictionId},
    );

    try {
      final requestUrl = '$_baseUrl/predictions/$predictionId';
      developer.log(
        'Sending status check request',
        name: 'ReplicateService',
        error: {'url': requestUrl},
      );

      final response = await http.get(
        Uri.parse(requestUrl),
        headers: {
          'Authorization': 'Token $_apiKey',
        },
      );

      developer.log(
        'Received status check response',
        name: 'ReplicateService',
        error: {
          'statusCode': response.statusCode,
          'headers': response.headers,
          'body': response.body,
        },
      );

      if (response.statusCode == 429) {
        final error = jsonDecode(response.body);
        final errorMsg =
            'Rate limit exceeded: ${error['detail']}. Please try again later.';
        developer.log(
          'Rate limit exceeded during status check',
          name: 'ReplicateService',
          error: {
            'detail': error['detail'],
            'headers': response.headers,
          },
        );
        throw Exception(errorMsg);
      }

      if (response.statusCode != 200) {
        final error = jsonDecode(response.body);
        final errorMsg =
            'Failed to check generation status: ${error['detail'] ?? response.body}';
        developer.log(
          'Status check failed',
          name: 'ReplicateService',
          error: {
            'statusCode': response.statusCode,
            'error': error,
            'headers': response.headers,
          },
        );
        throw Exception(errorMsg);
      }

      final result = jsonDecode(response.body);
      developer.log(
        'Status check result',
        name: 'ReplicateService',
        error: {
          'predictionId': predictionId,
          'status': result['status'],
          'output': result['output'],
          'error': result['error'],
          'logs': result['logs'],
          'headers': response.headers,
        },
      );

      // Handle different status values according to Replicate API
      switch (result['status']) {
        case 'starting':
          developer.log('Generation is starting', name: 'ReplicateService');
          return result;
        case 'processing':
          developer.log(
            'Generation is processing',
            name: 'ReplicateService',
            error: {'progress': result['progress']},
          );
          return result;
        case 'succeeded':
          if (result['output'] != null && result['output'] is String) {
            developer.log(
              'Generation succeeded',
              name: 'ReplicateService',
              error: {'output': result['output']},
            );
            return result;
          } else {
            const errorMsg = 'Invalid output format received from API';
            developer.log(
              'Invalid output format',
              name: 'ReplicateService',
              error: {'output': result['output']},
            );
            throw Exception(errorMsg);
          }
        case 'failed':
          final errorMsg =
              result['error'] ?? 'Generation failed without error details';
          developer.log(
            'Generation failed',
            name: 'ReplicateService',
            error: errorMsg,
          );
          throw Exception(errorMsg);
        case 'canceled':
          developer.log(
            'Generation was canceled',
            name: 'ReplicateService',
          );
          throw Exception('Video generation was canceled');
        default:
          final errorMsg = 'Unknown status: ${result['status']}';
          developer.log(
            'Unknown status received',
            name: 'ReplicateService',
            error: {'status': result['status']},
          );
          throw Exception(errorMsg);
      }
    } catch (e, stackTrace) {
      developer.log(
        'Error checking generation status',
        name: 'ReplicateService',
        error: e,
        stackTrace: stackTrace,
      );
      throw Exception('Error checking generation status: $e');
    }
  }
}
