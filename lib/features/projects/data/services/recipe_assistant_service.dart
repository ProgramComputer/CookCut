import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter/foundation.dart';

class RecipeAssistantService {
  final String baseUrl;
  final String apiKey;

  RecipeAssistantService._({
    required this.baseUrl,
    required this.apiKey,
  });

  factory RecipeAssistantService() {
    final ffmpegHost = dotenv.env['AWS_EC2_FFMPEG'] ?? '52.10.62.41';
    final ffmpegApiKey = dotenv.env['FFMPEG_API_KEY'] ?? '';

    debugPrint('=== RecipeAssistantService Initialization ===');
    debugPrint('FFMPEG Host: $ffmpegHost');
    debugPrint('FFMPEG API Key present: ${ffmpegApiKey.isNotEmpty}');
    debugPrint('All env variables: ${dotenv.env.keys.join(', ')}');

    return RecipeAssistantService._(
      baseUrl: 'http://$ffmpegHost:80',
      apiKey: ffmpegApiKey,
    );
  }

  Future<Map<String, dynamic>> getRecipeSuggestions({
    required String query,
    required String projectId,
    required Map<String, dynamic> recipeData,
  }) async {
    debugPrint('\n=== Making Recipe Assistant Request ===');
    debugPrint('URL: $baseUrl/recipe-assistant');
    debugPrint('API Key present: ${apiKey.isNotEmpty}');
    debugPrint('Project ID: $projectId');
    debugPrint('Query: $query');

    final headers = {
      'Content-Type': 'application/json',
      'x-api-key': apiKey,
    };

    debugPrint('Request Headers: ${jsonEncode(headers)}');

    final body = jsonEncode({
      'query': query,
      'projectId': projectId,
      'recipeData': recipeData,
    });

    debugPrint('Request Body: $body');

    final response = await http.post(
      Uri.parse('$baseUrl/recipe-assistant'),
      headers: headers,
      body: body,
    );

    debugPrint('\n=== Recipe Assistant Response ===');
    debugPrint('Status Code: ${response.statusCode}');

    final responseData = jsonDecode(response.body);
    debugPrint('\nRaw Response Data:');
    debugPrint(
        '- Has videoCommands: ${responseData.containsKey('videoCommands')}');
    debugPrint(
        '- Raw videoCommands: ${jsonEncode(responseData['videoCommands'])}');
    debugPrint('=== End Recipe Assistant Response ===\n');

    if (response.statusCode == 200) {
      return responseData;
    } else {
      throw Exception('Failed to get recipe suggestions: ${response.body}');
    }
  }
}
