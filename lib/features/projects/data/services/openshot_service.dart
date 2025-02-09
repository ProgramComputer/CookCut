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
    try {
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

      final projectData = jsonDecode(response.body);
      final projectId = projectData['id'];
      final projectUrl = projectData['url'];

      if (projectId == null || projectUrl == null) {
        print('Failed to get project ID or URL: ${response.body}');
        throw Exception('Failed to create project: ${response.body}');
      }

      print('Project created successfully: $projectId');
      return projectData;
    } catch (e) {
      print('Error creating project: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> importFile({
    required String projectId,
    required String fileUrl,
  }) async {
    try {
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

      final fileData = jsonDecode(response.body);
      final fileId = fileData['id'];
      final newFileUrl = fileData['url'];

      if (fileId == null || newFileUrl == null) {
        print('Failed to get file ID or URL: ${response.body}');
        throw Exception('Failed to import file: ${response.body}');
      }

      print('File imported successfully: $fileId');

      // Wait for file to be ready
      await _waitForFileReady(projectId, fileId);
      return fileData;
    } catch (e) {
      print('Error importing file: $e');
      rethrow;
    }
  }

  Future<void> _waitForFileReady(String projectId, String fileId) async {
    int attempts = 0;
    const maxAttempts = 30; // 30 seconds timeout

    while (attempts < maxAttempts) {
      try {
        final response = await http.get(
          Uri.parse('$baseUrl/projects/$projectId/files/$fileId/'),
          headers: {
            'Authorization': 'Token $apiToken',
          },
        );

        if (response.statusCode == 200) {
          final fileData = jsonDecode(response.body);
          if (fileData['status'] == 'ready') {
            print('File is ready for processing');
            return;
          }
        }

        await Future.delayed(const Duration(seconds: 1));
        attempts++;
      } catch (e) {
        print('Error checking file status: $e');
        await Future.delayed(const Duration(seconds: 1));
        attempts++;
      }
    }

    throw Exception('Timeout waiting for file to be ready');
  }

  Future<Map<String, dynamic>> createClip({
    required String projectId,
    required String fileId,
    required Duration startTime,
    required Duration endTime,
  }) async {
    try {
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

      final clipData = jsonDecode(response.body);
      final clipId = clipData['id'];
      final clipUrl = clipData['url'];

      if (clipId == null || clipUrl == null) {
        print('Failed to get clip ID or URL: ${response.body}');
        throw Exception('Failed to create clip: ${response.body}');
      }

      print('Clip created successfully: $clipId');
      return clipData;
    } catch (e) {
      print('Error creating clip: $e');
      rethrow;
    }
  }

  Future<String> exportProject({
    required String projectId,
    String format = 'mp4',
  }) async {
    try {
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

      final exportData = jsonDecode(response.body);
      final exportId = exportData['id'];
      final exportUrl = exportData['url'];

      if (exportId == null || exportUrl == null) {
        print('Failed to get export ID or URL: ${response.body}');
        throw Exception('Failed to export project: ${response.body}');
      }

      print('Export started successfully');

      // Wait for export to complete
      return await _waitForExportComplete(projectId, exportId);
    } catch (e) {
      print('Error exporting project: $e');
      rethrow;
    }
  }

  Future<String> _waitForExportComplete(
      String projectId, String exportId) async {
    int attempts = 0;
    const maxAttempts = 300; // 5 minutes timeout

    while (attempts < maxAttempts) {
      try {
        final response = await http.get(
          Uri.parse('$baseUrl/projects/$projectId/exports/$exportId/'),
          headers: {
            'Authorization': 'Token $apiToken',
          },
        );

        if (response.statusCode == 200) {
          final exportData = jsonDecode(response.body);
          if (exportData['status'] == 'completed') {
            print('Export completed successfully');
            return exportData['url'];
          } else if (exportData['status'] == 'failed') {
            throw Exception('Export failed: ${exportData['error']}');
          }
        }

        await Future.delayed(const Duration(seconds: 1));
        attempts++;
      } catch (e) {
        print('Error checking export status: $e');
        await Future.delayed(const Duration(seconds: 1));
        attempts++;
      }
    }

    throw Exception('Timeout waiting for export to complete');
  }

  Future<double> getExportProgress(String projectId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/projects/$projectId/'),
        headers: {
          'Authorization': 'Token $apiToken',
        },
      );

      if (response.statusCode != 200) {
        print('Failed to get project status: ${response.body}');
        throw Exception('Failed to get project status: ${response.body}');
      }

      final projectData = jsonDecode(response.body);
      final progress = (projectData['progress'] ?? 0.0) / 100.0;
      print('Export progress: ${(progress * 100).toStringAsFixed(1)}%');
      return progress;
    } catch (e) {
      print('Error getting export progress: $e');
      return 0.0;
    }
  }

  Future<String> trimVideo({
    required String videoUrl,
    required Duration startTime,
    required Duration endTime,
  }) async {
    try {
      print('Starting video trim operation...');
      print('Input video URL: $videoUrl');
      print('Trim points: ${startTime.inSeconds}s to ${endTime.inSeconds}s');

      // Create a new project
      final project =
          await createProject('Trim_${DateTime.now().millisecondsSinceEpoch}');
      final projectId = project['id'];
      print('Created project with ID: $projectId');

      // Import the video file
      final file = await importFile(
        projectId: projectId,
        fileUrl: videoUrl,
      );
      print('Imported file with ID: ${file['id']}');

      // Create a clip with the trim points
      await createClip(
        projectId: projectId,
        fileId: file['id'],
        startTime: startTime,
        endTime: endTime,
      );
      print('Created clip successfully');

      // Export the project
      final exportUrl =
          await exportProject(projectId: projectId, format: 'mp4');
      print('Export completed. URL: $exportUrl');

      return exportUrl;
    } catch (e) {
      print('Error in trimVideo operation: $e');
      rethrow;
    }
  }
}
