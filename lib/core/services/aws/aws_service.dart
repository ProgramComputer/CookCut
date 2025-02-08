import 'dart:io';

abstract class AwsService {
  /// Upload a file to S3
  Future<String> uploadFileToS3(File file, String bucket, String key);

  /// Download a file from S3
  Future<File> downloadFileFromS3(String bucket, String key, String localPath);

  /// Delete a file from S3
  Future<void> deleteFileFromS3(String bucket, String key);

  /// Generate a pre-signed URL for temporary access
  Future<String> generatePresignedUrl(String bucket, String key,
      {Duration? expiration});

  /// List objects in a bucket
  Future<List<String>> listObjects(String bucket, {String? prefix});
}
