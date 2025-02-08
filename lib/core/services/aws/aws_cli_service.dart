import 'dart:io';
import 'package:process_run/process_run.dart';
import 'aws_service.dart';

class AwsCliService implements AwsService {
  final String _profile;
  final String _region;

  AwsCliService({
    String profile = 'default',
    String region = 'us-east-1',
  })  : _profile = profile,
        _region = region;

  Future<ProcessResult> _runAwsCommand(List<String> args) async {
    var shell = Shell();
    final result = await shell.run('aws', arguments: [
      '--profile',
      _profile,
      '--region',
      _region,
      ...args,
    ]);

    if (result.first.exitCode != 0) {
      throw Exception('AWS CLI command failed: ${result.first.stderr}');
    }

    return result.first;
  }

  @override
  Future<String> uploadFileToS3(File file, String bucket, String key) async {
    final args = [
      's3',
      'cp',
      file.path,
      's3://$bucket/$key',
    ];

    await _runAwsCommand(args);
    return 'https://$bucket.s3.$_region.amazonaws.com/$key';
  }

  @override
  Future<File> downloadFileFromS3(
      String bucket, String key, String localPath) async {
    final args = [
      's3',
      'cp',
      's3://$bucket/$key',
      localPath,
    ];

    await _runAwsCommand(args);
    return File(localPath);
  }

  @override
  Future<void> deleteFileFromS3(String bucket, String key) async {
    final args = [
      's3',
      'rm',
      's3://$bucket/$key',
    ];

    await _runAwsCommand(args);
  }

  @override
  Future<String> generatePresignedUrl(String bucket, String key,
      {Duration? expiration}) async {
    final args = [
      's3',
      'presign',
      's3://$bucket/$key',
      '--expires-in',
      '${expiration?.inSeconds ?? 3600}',
    ];

    final result = await _runAwsCommand(args);
    return result.stdout.toString().trim();
  }

  @override
  Future<List<String>> listObjects(String bucket, {String? prefix}) async {
    final args = [
      's3',
      'ls',
      's3://$bucket/${prefix ?? ''}',
      '--recursive',
    ];

    final result = await _runAwsCommand(args);
    return result.stdout
        .toString()
        .split('\n')
        .where((line) => line.isNotEmpty)
        .map((line) => line.split(' ').last)
        .toList();
  }
}
