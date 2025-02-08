import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

class VideoEditingService {
  final String baseUrl;
  final String apiToken;

  VideoEditingService({
    String? baseUrl,
    String? apiToken,
  })  : baseUrl = baseUrl ??
            dotenv.env['OPENSHOT_API_URL'] ??
            'http://cloud.openshot.org',
        apiToken = apiToken ?? dotenv.env['OPENSHOT_API_TOKEN'] ?? '';

  Map<String, String> get _headers => {
        'Authorization': 'Bearer $apiToken',
        'Content-Type': 'application/x-www-form-urlencoded',
      };

  Future<Map<String, dynamic>> createProject({
    required String name,
    int width = 1920,
    int height = 1080,
    int fpsNum = 30,
    int fpsDen = 1,
    int sampleRate = 44100,
    int channels = 2,
    int channelLayout = 3,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/projects/'),
      headers: _headers,
      body: {
        'name': name,
        'width': width.toString(),
        'height': height.toString(),
        'fps_num': fpsNum.toString(),
        'fps_den': fpsDen.toString(),
        'sample_rate': sampleRate.toString(),
        'channels': channels.toString(),
        'channel_layout': channelLayout.toString(),
        'json': '{}',
      },
    );

    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to create project: ${response.body}');
    }
  }

  Future<Map<String, dynamic>> uploadFile({
    required String projectUrl,
    required List<int> fileBytes,
    required String fileName,
  }) async {
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$projectUrl/files/'),
    );

    request.headers['Authorization'] = _headers['Authorization']!;
    request.fields['project'] = projectUrl;
    request.fields['json'] = '{}';

    request.files.add(
      http.MultipartFile.fromBytes(
        'media',
        fileBytes,
        filename: fileName,
      ),
    );

    final response = await request.send();
    final responseBody = await response.stream.bytesToString();

    if (response.statusCode == 200) {
      return json.decode(responseBody);
    } else {
      throw Exception('Failed to upload file: $responseBody');
    }
  }

  Future<Map<String, dynamic>> createClip({
    required String fileUrl,
    required String projectUrl,
    double position = 0.0,
    double start = 0.0,
    required double end,
    int layer = 0,
  }) async {
    final response = await http.post(
      Uri.parse('$projectUrl/clips/'),
      headers: _headers,
      body: {
        'file': fileUrl,
        'position': position.toString(),
        'start': start.toString(),
        'end': end.toString(),
        'layer': layer.toString(),
        'project': projectUrl,
        'json': '{}',
      },
    );

    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to create clip: ${response.body}');
    }
  }

  Future<Map<String, dynamic>> exportVideo({
    required String projectUrl,
    String videoFormat = 'mp4',
    String videoCodec = 'libx264',
    int videoBitrate = 8000000,
    String audioCodec = 'ac3',
    int audioBitrate = 1920000,
    int? startFrame,
    int? endFrame,
  }) async {
    final response = await http.post(
      Uri.parse('$projectUrl/exports/'),
      headers: _headers,
      body: {
        'video_format': videoFormat,
        'video_codec': videoCodec,
        'video_bitrate': videoBitrate.toString(),
        'audio_codec': audioCodec,
        'audio_bitrate': audioBitrate.toString(),
        if (startFrame != null) 'start_frame': startFrame.toString(),
        if (endFrame != null) 'end_frame': endFrame.toString(),
        'project': projectUrl,
        'json': '{}',
      },
    );

    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to export video: ${response.body}');
    }
  }

  Future<Map<String, dynamic>> getExportStatus(String exportUrl) async {
    final response = await http.get(
      Uri.parse(exportUrl),
      headers: _headers,
    );

    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to get export status: ${response.body}');
    }
  }

  Future<String> waitForExport(String exportUrl) async {
    bool isExported = false;
    int countdown = 500; // Maximum 500 attempts
    Map<String, dynamic> status = {};

    while (!isExported && countdown > 0) {
      status = await getExportStatus(exportUrl);
      final progress = double.tryParse(status['progress']?.toString() ?? '0');

      if (progress == 100.0) {
        isExported = true;
      } else {
        await Future.delayed(const Duration(seconds: 5));
        countdown--;
      }
    }

    if (!isExported) {
      throw Exception('Export timed out');
    }

    return status['output'] as String;
  }
}
