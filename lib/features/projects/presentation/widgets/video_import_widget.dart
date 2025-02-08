import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import 'package:mime/mime.dart';

class VideoImportWidget extends StatefulWidget {
  final Function(File file)? onFileSelected;
  final double? width;
  final double? height;

  const VideoImportWidget({
    Key? key,
    this.onFileSelected,
    this.width,
    this.height,
  }) : super(key: key);

  @override
  State<VideoImportWidget> createState() => _VideoImportWidgetState();
}

class _VideoImportWidgetState extends State<VideoImportWidget> {
  bool _isDragging = false;
  bool _isLoading = false;

  Future<void> _pickVideo() async {
    try {
      setState(() => _isLoading = true);

      final result = await FilePicker.platform.pickFiles(
        type: FileType.video,
        allowMultiple: false,
        allowedExtensions: ['mp4', 'mov'],
      );

      if (result != null && result.files.isNotEmpty) {
        final file = File(result.files.first.path!);
        _validateAndProcessVideo(file);
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _validateAndProcessVideo(File file) async {
    final mimeType = lookupMimeType(file.path);
    if (mimeType == null || !mimeType.startsWith('video/')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a valid video file')),
      );
      return;
    }

    final fileSize = await file.length();
    if (fileSize > 1024 * 1024 * 1024) {
      // 1GB
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('File size exceeds 1GB limit')),
      );
      return;
    }

    if (fileSize > 500 * 1024 * 1024) {
      // 500MB
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Large file size may result in longer upload times'),
          duration: Duration(seconds: 5),
        ),
      );
    }

    widget.onFileSelected?.call(file);
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.width ?? 400,
      height: widget.height ?? 300,
      child: DragTarget<String>(
        builder: (context, candidateData, rejectedData) {
          return Container(
            decoration: BoxDecoration(
              color: _isDragging
                  ? Theme.of(context).primaryColor.withOpacity(0.1)
                  : Colors.grey.withOpacity(0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _isDragging
                    ? Theme.of(context).primaryColor
                    : Colors.grey.withOpacity(0.3),
                width: 2,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.video_library_outlined,
                  size: 48,
                  color: _isDragging
                      ? Theme.of(context).primaryColor
                      : Colors.grey,
                ),
                const SizedBox(height: 16),
                Text(
                  'Drag & Drop Video Here',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  'or',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 8),
                ElevatedButton.icon(
                  onPressed: _isLoading ? null : _pickVideo,
                  icon: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.upload_file),
                  label:
                      Text(_isLoading ? 'Processing...' : 'Choose from Device'),
                ),
                const SizedBox(height: 8),
                ElevatedButton.icon(
                  onPressed: _isLoading
                      ? null
                      : () {
                          // TODO: Implement camera recording
                        },
                  icon: const Icon(Icons.videocam),
                  label: const Text('Record Video'),
                ),
                const SizedBox(height: 16),
                Text(
                  'Supported: MP4, MOV up to 1GB',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.grey,
                      ),
                ),
              ],
            ),
          );
        },
        onWillAcceptWithDetails: (data) {
          setState(() => _isDragging = true);
          return true;
        },
        onLeave: (data) {
          setState(() => _isDragging = false);
        },
        onAcceptWithDetails: (data) {
          setState(() => _isDragging = false);
          // TODO: Handle dropped file
        },
      ),
    );
  }
}
