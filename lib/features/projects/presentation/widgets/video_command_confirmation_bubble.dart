import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/models/recipe_suggestion.dart';
import '../../data/services/ffmpeg_service.dart';
import '../bloc/media_bloc.dart';
import '../../domain/entities/media_asset.dart';
import 'package:uuid/uuid.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class VideoCommandConfirmationBubble extends StatefulWidget {
  final VideoCommand command;
  final String projectId;
  final Function(String outputUrl) onSuccess;

  const VideoCommandConfirmationBubble({
    super.key,
    required this.command,
    required this.projectId,
    required this.onSuccess,
  });

  @override
  State<VideoCommandConfirmationBubble> createState() =>
      _VideoCommandConfirmationBubbleState();
}

class _VideoCommandConfirmationBubbleState
    extends State<VideoCommandConfirmationBubble> {
  bool _isProcessing = false;
  String? _error;
  double _progress = 0;
  late final FFmpegService _ffmpegService;

  @override
  void initState() {
    super.initState();
    _ffmpegService = FFmpegService();
  }

  Future<void> _executeCommand() async {
    setState(() {
      _isProcessing = true;
      _error = null;
      _progress = 0;
    });

    try {
      // Execute FFmpeg command
      final result = await _ffmpegService.exportVideoWithOverlays(
        videoUrl: widget.command.inputFiles.first,
        textOverlays: [],
        timerOverlays: [],
        recipeOverlays: [],
        aspectRatio: 16 / 9,
        projectId: widget.projectId,
        backgroundMusic: null,
      );

      if (!mounted) return;

      // Start polling for status
      String? jobId = result['jobId'];
      if (jobId != null) {
        bool isComplete = false;
        int retryCount = 0;
        const maxRetries = 60; // 5 minutes with 5-second intervals

        while (!isComplete && retryCount < maxRetries && mounted) {
          try {
            final status = await _ffmpegService.checkJobStatus(jobId);
            print('📊 Job Status Update - ${DateTime.now()}: $status');

            if (!mounted) break;

            setState(() {
              _progress = (status['progress'] ?? 0) / 100;
            });

            if (status['status'] == 'complete' &&
                status['output_url'] != null) {
              isComplete = true;
              // Create Firestore document with the completed URL
              final docRef = await FirebaseFirestore.instance
                  .collection('projects')
                  .doc(widget.projectId)
                  .collection('media_assets')
                  .add({
                'fileName':
                    'processed_${DateTime.now().millisecondsSinceEpoch}.mp4',
                'fileUrl': status['output_url'],
                'storagePath':
                    'media/${widget.projectId}/processed/processed_${DateTime.now().millisecondsSinceEpoch}.mp4',
                'type': MediaType.editedClip.name,
                'fileSize': 0,
                'uploadedAt': FieldValue.serverTimestamp(),
                'metadata': {
                  'operation': widget.command.operation,
                  'description': widget.command.description,
                  'originalCommand': widget.command.ffmpegCommand,
                  'inputFiles': widget.command.inputFiles,
                },
                'position': 0,
                'layer': 0,
                'status': 'ready',
                'thumbnailUrl': null,
              });

              // Create MediaAsset
              final mediaAsset = MediaAsset(
                id: docRef.id,
                projectId: widget.projectId,
                type: MediaType.editedClip,
                fileUrl: status['output_url'],
                fileName:
                    'processed_${DateTime.now().millisecondsSinceEpoch}.mp4',
                fileSize: 0,
                uploadedAt: DateTime.now(),
                position: 0,
                metadata: {
                  'operation': widget.command.operation,
                  'description': widget.command.description,
                  'originalCommand': widget.command.ffmpegCommand,
                  'inputFiles': widget.command.inputFiles,
                },
              );

              context.read<MediaBloc>().add(AddGeneratedMedia(mediaAsset));
              widget.onSuccess(status['output_url']);
            } else if (status['status'] == 'failed') {
              throw Exception(status['error'] ?? 'Processing failed');
            }

            if (!isComplete) {
              retryCount++;
              await Future.delayed(const Duration(seconds: 5));
            }
          } catch (statusError) {
            print('❌ Error checking status: $statusError');
            retryCount++;
            await Future.delayed(const Duration(seconds: 5));
          }
        }

        if (!isComplete && retryCount >= maxRetries) {
          throw Exception('Processing timed out after 5 minutes');
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isProcessing = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            backgroundColor: Colors.green,
            child: const Icon(Icons.assistant, color: Colors.white),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.secondaryContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.command.operation.toUpperCase(),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(widget.command.description),
                  const SizedBox(height: 16),
                  if (_isProcessing) ...[
                    LinearProgressIndicator(value: _progress),
                    const SizedBox(height: 8),
                    Text(
                        'Processing... ${(_progress * 100).toStringAsFixed(0)}%'),
                  ] else if (_error != null) ...[
                    Text(
                      _error!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ] else ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () {
                            // Just remove this bubble
                            widget.onSuccess('cancelled');
                          },
                          child: const Text('Cancel'),
                        ),
                        const SizedBox(width: 8),
                        FilledButton(
                          onPressed: _executeCommand,
                          child: const Text('Confirm'),
                        ),
                      ],
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
