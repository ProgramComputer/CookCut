import 'dart:io';
import 'package:path/path.dart' as path;
// import 'package:http/http.dart' as http;
// import 'package:aws_s3_api/s3-2006-03-01.dart';
// import 'package:shared_aws_api/shared.dart';
// import 'package:flutter_dotenv/flutter_dotenv.dart';

class S3Service {
  // late final S3 _s3Client;

  S3Service() {
    // Dummy constructor - no actual AWS initialization
    print('Initialized mock S3 service');
  }

  /// Get a pre-signed URL for uploading a file
  Future<String> getUploadUrl({
    required String projectId,
    required String fileName,
    required String contentType,
  }) async {
    try {
      // Simulate network delay
      await Future.delayed(const Duration(milliseconds: 500));

      // Return a dummy URL
      return 'https://dummy-s3.amazonaws.com/projects/$projectId/media/$fileName';
    } catch (e) {
      throw Exception('Failed to get upload URL: $e');
    }
  }

  /// Upload a file using pre-signed URL
  Future<String> uploadFile({
    required String projectId,
    required File file,
    String? customFileName,
  }) async {
    final fileName = customFileName ?? path.basename(file.path);
    final contentType = _getContentType(fileName);

    try {
      // Simulate network delay
      await Future.delayed(const Duration(seconds: 1));

      // Return a dummy URL
      final url =
          'https://dummy-s3.amazonaws.com/projects/$projectId/media/$fileName';
      print('Mock uploaded file to: $url');
      print('File size: ${await file.length()} bytes');
      print('Content type: $contentType');

      return url;
    } catch (e) {
      throw Exception('Failed to upload file: $e');
    }
  }

  /// Get a pre-signed URL for downloading a file
  Future<String> getDownloadUrl(String fileUrl) async {
    try {
      // Simulate network delay
      await Future.delayed(const Duration(milliseconds: 500));

      // Return the same URL for dummy implementation
      return fileUrl;
    } catch (e) {
      throw Exception('Failed to get download URL: $e');
    }
  }

  /// Helper method to determine content type
  String _getContentType(String fileName) {
    final ext = path.extension(fileName).toLowerCase();
    switch (ext) {
      case '.mp4':
        return 'video/mp4';
      case '.mov':
        return 'video/quicktime';
      case '.jpg':
      case '.jpeg':
        return 'image/jpeg';
      case '.png':
        return 'image/png';
      default:
        return 'application/octet-stream';
    }
  }

  /// Direct upload to S3 (alternative to pre-signed URLs)
  Future<void> directUpload({
    required String projectId,
    required File file,
    String? customFileName,
  }) async {
    try {
      final fileName = customFileName ?? path.basename(file.path);
      final contentType = _getContentType(fileName);

      // Simulate network delay
      await Future.delayed(const Duration(seconds: 2));

      print('Mock direct upload:');
      print('- File: $fileName');
      print('- Size: ${await file.length()} bytes');
      print('- Type: $contentType');
      print('- Project: $projectId');
    } catch (e) {
      throw Exception('Failed to upload file directly: $e');
    }
  }

  /// Clean up resources
  void dispose() {
    // No actual cleanup needed in mock implementation
    print('Disposed mock S3 service');
  }
}
