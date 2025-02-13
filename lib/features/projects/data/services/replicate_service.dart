import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class ReplicateService {
  final String _baseUrl = 'https://api.replicate.com/v1';
  late final String _apiKey;

  ReplicateService() {
    _apiKey = dotenv.env['REPLICATE_API_KEY'] ?? '';
    if (_apiKey.isEmpty) {
      throw Exception('REPLICATE_API_KEY not found in environment variables');
    }
  }

  Future<Map<String, dynamic>> generateRecipeVideo({
    required String prompt,
    required int durationSeconds,
    String? style,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/predictions'),
        headers: {
          'Authorization': 'Token $_apiKey',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'version':
              'e8c8fa6f1b4c39d2a0a0eab3c3e7c2a2a5c4f2a1', // Replace with actual version
          'input': {
            'prompt': prompt,
            'duration': durationSeconds,
            'style': style ?? 'modern cooking',
          },
        }),
      );

      if (response.statusCode != 201) {
        throw Exception('Failed to start video generation: ${response.body}');
      }

      final prediction = jsonDecode(response.body);
      return prediction;
    } catch (e) {
      throw Exception('Error generating video: $e');
    }
  }

  Future<Map<String, dynamic>> checkGenerationStatus(
      String predictionId) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/predictions/$predictionId'),
        headers: {
          'Authorization': 'Token $_apiKey',
        },
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to check generation status: ${response.body}');
      }

      return jsonDecode(response.body);
    } catch (e) {
      throw Exception('Error checking generation status: $e');
    }
  }
}
