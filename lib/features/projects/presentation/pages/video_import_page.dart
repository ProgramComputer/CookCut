import 'package:flutter/material.dart';
import 'dart:io';
import '../widgets/video_import_widget.dart';
import '../../data/services/s3_service.dart';

class VideoImportPage extends StatefulWidget {
  final String projectId;

  const VideoImportPage({
    Key? key,
    required this.projectId,
  }) : super(key: key);

  @override
  State<VideoImportPage> createState() => _VideoImportPageState();
}

class _VideoImportPageState extends State<VideoImportPage> {
  final S3Service _s3Service = S3Service();
  bool _isUploading = false;
  double _uploadProgress = 0.0;

  Future<void> _handleFileSelected(File file) async {
    try {
      setState(() {
        _isUploading = true;
        _uploadProgress = 0.0;
      });

      // Upload to S3
      final fileUrl = await _s3Service.uploadFile(
        projectId: widget.projectId,
        file: file,
      );

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Video uploaded successfully'),
          backgroundColor: Colors.green,
        ),
      );

      // TODO: Navigate to video editor or update project media list
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Upload failed: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isUploading = false;
        _uploadProgress = 0.0;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Import Video'),
        elevation: 0,
      ),
      body: Stack(
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 600),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  VideoImportWidget(
                    onFileSelected: _handleFileSelected,
                  ),
                  if (_isUploading) ...[
                    const SizedBox(height: 24),
                    LinearProgressIndicator(value: _uploadProgress),
                    const SizedBox(height: 8),
                    Text(
                      'Uploading... ${(_uploadProgress * 100).toStringAsFixed(1)}%',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
