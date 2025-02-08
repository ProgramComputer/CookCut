import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

class OpenshotService {
  final String baseUrl;
  final String apiToken;

  OpenshotService({
    String? baseUrl,
    String? apiToken,
  })  : baseUrl = baseUrl ?? dotenv.env['OPENSHOT_API_URL'] ?? '',
        apiToken = apiToken ?? dotenv.env['OPENSHOT_API_TOKEN'] ?? '';

  Future<Map<String, dynamic>> createProject(String name) async {
    final response = await http.post(
      Uri.parse('$baseUrl/projects/'),
      headers: {
        'Authorization': 'Token $apiToken',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'name': name,
        'width': 1920,
        'height': 1080,
        'fps_num': 30,
        'fps_den': 1,
        'sample_rate': 44100,
        'channels': 2,
        'channel_layout': 3,
      }),
    );

    if (response.statusCode != 201) {
      throw Exception('Failed to create project: ${response.body}');
    }

    return jsonDecode(response.body);
  }

  Future<Map<String, dynamic>> importFile({
    required String projectId,
    required String fileUrl,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/projects/$projectId/files/'),
      headers: {
        'Authorization': 'Token $apiToken',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'import_url': fileUrl,
      }),
    );

    if (response.statusCode != 201) {
      throw Exception('Failed to import file: ${response.body}');
    }

    return jsonDecode(response.body);
  }

  Future<Map<String, dynamic>> createClip({
    required String projectId,
    required String fileId,
    required Duration startTime,
    required Duration endTime,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/projects/$projectId/clips/'),
      headers: {
        'Authorization': 'Token $apiToken',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'file_id': fileId,
        'position': 0,
        'start': startTime.inMilliseconds / 1000,
        'end': endTime.inMilliseconds / 1000,
        'layer': 0,
      }),
    );

    if (response.statusCode != 201) {
      throw Exception('Failed to create clip: ${response.body}');
    }

    return jsonDecode(response.body);
  }

  Future<String> exportProject({
    required String projectId,
    String format = 'mp4',
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/projects/$projectId/exports/'),
      headers: {
        'Authorization': 'Token $apiToken',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'export': {
          'format': format,
          'video_codec': 'libx264',
          'video_bitrate': 8000000,
          'audio_codec': 'aac',
          'audio_bitrate': 192000,
          'start_frame': 1,
          'end_frame': -1,
          'fps_num': 30,
          'fps_den': 1,
          'width': 1920,
          'height': 1080,
          'pixel_format': 1,
          'sample_rate': 44100,
          'channels': 2,
          'channel_layout': 3,
        },
      }),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to export project: ${response.body}');
    }

    final exportData = jsonDecode(response.body);
    return exportData['url'];
  }

  Future<double> getExportProgress(String projectId) async {
    final response = await http.get(
      Uri.parse('$baseUrl/projects/$projectId/'),
      headers: {
        'Authorization': 'Token $apiToken',
      },
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to get project status: ${response.body}');
    }

    final projectData = jsonDecode(response.body);
    return (projectData['progress'] ?? 0.0) / 100.0;
  }

  Future<String> trimVideo({
    required String videoUrl,
    required Duration startTime,
    required Duration endTime,
  }) async {
    // Create a new project
    final project =
        await createProject('Trim_${DateTime.now().millisecondsSinceEpoch}');
    final projectId = project['id'];

    // Import the video file
    final file = await importFile(
      projectId: projectId,
      fileUrl: videoUrl,
    );

    // Create a clip with the trim points
    await createClip(
      projectId: projectId,
      fileId: file['id'],
      startTime: startTime,
      endTime: endTime,
    );

    // Export the project with default format
    return await exportProject(projectId: projectId, format: 'mp4');
  }
}
