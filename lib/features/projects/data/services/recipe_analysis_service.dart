import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/recipe_analysis.dart';
import 'ffmpeg_service.dart';

class RecipeAnalysisService {
  final FFmpegService _ffmpegService;

  RecipeAnalysisService(this._ffmpegService);

  Future<RecipeAnalysis> analyzeVideo({
    required String videoPath,
    required String projectId,
    Function(String message)? onProgress,
  }) async {
    try {
      onProgress?.call('Starting recipe analysis...');

      final response = await http.post(
        Uri.parse('${_ffmpegService.baseUrl}/analyze-recipe'),
        headers: _ffmpegService.headers,
        body: jsonEncode({
          'videoPath': videoPath,
          'projectId': projectId,
        }),
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to analyze recipe: ${response.body}');
      }

      final data = jsonDecode(response.body);
      onProgress?.call('Recipe analysis completed!');

      return RecipeAnalysis.fromJson(data);
    } catch (e) {
      onProgress?.call('Error analyzing recipe: $e');
      rethrow;
    }
  }
}
