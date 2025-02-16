import 'package:test/test.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'dart:convert';

void main() {
  final baseUrl = 'http://44.202.46.242'; // Direct IP address for testing

  test('Test FFmpeg server direct URL processing', () async {
    print('Testing FFmpeg server at: $baseUrl');

    // 1. Test health endpoint
    try {
      final healthResponse = await http.get(Uri.parse('$baseUrl/health'));
      print('Health check status: ${healthResponse.statusCode}');
      print('Health check response: ${healthResponse.body}');
      expect(healthResponse.statusCode, 200);
    } catch (e) {
      print('Health check failed: $e');
      rethrow;
    }

    // 2. Test video processing with direct URL
    final testVideoUrl =
        'https://lusbocfxarkubkbskcdl.supabase.co/storage/v1/object/public/cookcut-media/projects/A6Gv1Q2lVhaltK90wU1W/media/raw/cooking.mp4';

    try {
      print('Sending process-url request...');
      final response = await http.post(
        Uri.parse('$baseUrl/process-url'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'videoUrl': testVideoUrl,
          'command': 'ffmpeg -i input.mp4 -t 5 -c copy output.mp4'
        }),
      );

      print('Process URL response status: ${response.statusCode}');
      print('Process URL response: ${response.body}');

      expect(response.statusCode, 200);
      final jsonResponse = jsonDecode(response.body);
      expect(jsonResponse['jobId'], isNotNull);

      // Monitor progress
      final jobId = jsonResponse['jobId'];
      var isComplete = false;
      var attempts = 0;
      const maxAttempts = 30; // 30 seconds timeout

      while (!isComplete && attempts < maxAttempts) {
        final statusResponse = await http.get(
          Uri.parse('$baseUrl/progress/$jobId'),
        );

        final status = jsonDecode(statusResponse.body);
        print(
            'Job status: ${status['status']}, Progress: ${status['progress']}%');

        if (status['status'] == 'complete') {
          isComplete = true;

          // Try to get the output file
          final outputResponse = await http.get(
            Uri.parse('$baseUrl/output/$jobId'),
          );
          expect(outputResponse.statusCode, 200);
          expect(outputResponse.bodyBytes.length, greaterThan(0));
          print(
              'Successfully retrieved output file: ${outputResponse.bodyBytes.length} bytes');
          break;
        }

        if (status['status'] == 'failed') {
          throw Exception('Processing failed: ${status['error']}');
        }

        await Future.delayed(const Duration(seconds: 1));
        attempts++;
      }

      expect(isComplete, true,
          reason: 'Processing did not complete within 30 seconds');
    } catch (e) {
      print('Error during test: $e');
      rethrow;
    }
  });
}
