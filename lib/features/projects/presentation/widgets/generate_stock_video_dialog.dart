import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:developer' as developer;
import '../../data/services/replicate_service.dart';
import '../../domain/entities/media_asset.dart';
import '../../domain/entities/project.dart';
import '../../data/services/media_processing_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as path;
import 'package:uuid/uuid.dart';
import 'dart:io';

class GenerateStockVideoDialog extends StatefulWidget {
  final Project project;
  final Function(MediaAsset) onVideoGenerated;

  const GenerateStockVideoDialog({
    super.key,
    required this.project,
    required this.onVideoGenerated,
  });

  @override
  State<GenerateStockVideoDialog> createState() =>
      _GenerateStockVideoDialogState();
}

class _GenerateStockVideoDialogState extends State<GenerateStockVideoDialog> {
  final _formKey = GlobalKey<FormState>();
  late final ReplicateService _replicateService;
  final _promptController = TextEditingController();
  final _mediaProcessingService = MediaProcessingService(
    supabase: Supabase.instance.client,
  );

  @override
  void initState() {
    super.initState();
    try {
      _replicateService = ReplicateService();
      developer.log(
        'ReplicateService initialized in dialog',
        name: 'GenerateStockVideoDialog',
      );
    } catch (e) {
      developer.log(
        'Failed to initialize ReplicateService',
        name: 'GenerateStockVideoDialog',
        error: e,
      );
      // Set error state to show in UI
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {
            _error = 'Failed to initialize video generation service: $e';
          });
        }
      });
    }
  }

  int _duration = 5;
  bool _isGenerating = false;
  String? _error;
  double _progress = 0;
  Timer? _statusCheckTimer;

  bool get _hasValidDescription => widget.project.description.trim().isNotEmpty;

  @override
  void dispose() {
    _statusCheckTimer?.cancel();
    _promptController.dispose();
    super.dispose();
  }

  String _buildFullPrompt() {
    final customPrompt = _promptController.text.trim();
    final projectDesc = widget.project.description.trim();

    if (customPrompt.isEmpty) {
      return projectDesc;
    }

    return '$customPrompt. $projectDesc';
  }

  Future<void> _startGeneration() async {
    developer.log(
      'Generate button clicked',
      name: 'GenerateStockVideoDialog',
      error: {
        'hasValidDescription': _hasValidDescription,
        'prompt': _buildFullPrompt(),
        'duration': _duration,
      },
    );

    if (!_hasValidDescription) {
      setState(() {
        _error = 'Please add a project description before generating a video';
      });
      developer.log(
        'Generation blocked - no valid description',
        name: 'GenerateStockVideoDialog',
      );
      return;
    }

    if (!_formKey.currentState!.validate()) {
      developer.log(
        'Form validation failed',
        name: 'GenerateStockVideoDialog',
      );
      return;
    }
    _formKey.currentState!.save();

    setState(() {
      _isGenerating = true;
      _error = null;
      _progress = 0;
    });

    try {
      developer.log(
        'Calling ReplicateService.generateStockVideo',
        name: 'GenerateStockVideoDialog',
        error: {
          'prompt': _buildFullPrompt(),
          'duration': _duration,
        },
      );

      final prediction = await _replicateService.generateStockVideo(
        prompt: _buildFullPrompt(),
        durationSeconds: _duration,
      );

      if (!mounted) return;

      final predictionId = prediction['id'];
      _monitorGenerationStatus(predictionId);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _isGenerating = false;
      });
    }
  }

  Future<void> _uploadToSupabase(String videoUrl) async {
    try {
      setState(() => _progress = 0.9); // Start upload phase

      // Download video from Replicate
      final videoResponse = await http.get(Uri.parse(videoUrl));
      if (videoResponse.statusCode != 200) {
        throw Exception('Failed to download video from Replicate');
      }

      // Generate unique IDs for the files
      final videoId = const Uuid().v4();
      final videoFileName = 'generated_video_$videoId.mp4';
      final thumbnailFileName = 'thumbnail_$videoId.jpg';

      // Create temporary files
      final tempDir = await Directory.systemTemp.createTemp('video_upload');
      final videoFile = File('${tempDir.path}/$videoFileName');
      await videoFile.writeAsBytes(videoResponse.bodyBytes);

      // Upload paths
      final videoPath = 'media/${widget.project.id}/raw/$videoFileName';
      final thumbnailPath =
          'media/${widget.project.id}/thumbnails/$thumbnailFileName';

      // Upload video to Supabase
      await Supabase.instance.client.storage.from('cookcut-media').upload(
            videoPath,
            videoFile,
            fileOptions:
                const FileOptions(contentType: 'video/mp4', upsert: true),
          );

      setState(() => _progress = 0.95); // Video uploaded

      // Generate thumbnail (it's uploaded within the service)
      final thumbnailUrl = await _mediaProcessingService.generateThumbnail(
        videoFile.path,
        projectId: widget.project.id,
      );

      // Clean up temp files
      await tempDir.delete(recursive: true);

      setState(() => _progress = 1.0); // Thumbnail generated

      // Get public URLs
      final videoPublicUrl = Supabase.instance.client.storage
          .from('cookcut-media')
          .getPublicUrl(videoPath);

      // Create MediaAsset with exact Firestore schema
      final mediaAsset = MediaAsset(
        id: videoId,
        projectId: widget.project.id,
        fileName: videoFileName,
        fileSize: videoResponse.contentLength ?? 0,
        fileUrl: videoPublicUrl,
        metadata: {
          'extension': 'mp4',
          'fileType': 'video',
          'projectId': widget.project.id,
          'generated': true,
          'prompt': _buildFullPrompt(),
          'originalReplicateUrl': videoUrl,
          'storagePath': videoPath,
          'thumbnailStoragePath': thumbnailPath,
        },
        type: MediaType.rawFootage,
        thumbnailUrl: thumbnailUrl,
        uploadedAt: DateTime.now(),
        position: 0,
        layer: 0,
      );

      if (!mounted) return;
      widget.onVideoGenerated(mediaAsset);
      Navigator.of(context).pop();
    } catch (e, stackTrace) {
      developer.log(
        'Error uploading to Supabase',
        name: 'GenerateStockVideoDialog',
        error: e,
        stackTrace: stackTrace,
      );
      if (!mounted) return;
      setState(() {
        _error = 'Error uploading video: $e';
        _isGenerating = false;
      });
    }
  }

  void _monitorGenerationStatus(String predictionId) {
    developer.log(
      'Starting generation status monitoring',
      name: 'GenerateStockVideoDialog',
      error: {'predictionId': predictionId},
    );

    _statusCheckTimer?.cancel();
    _statusCheckTimer =
        Timer.periodic(const Duration(seconds: 5), (timer) async {
      if (!mounted) {
        timer.cancel();
        return;
      }

      try {
        final status =
            await _replicateService.checkGenerationStatus(predictionId);

        if (!mounted) {
          timer.cancel();
          return;
        }

        developer.log(
          'Received status update',
          name: 'GenerateStockVideoDialog',
          error: {
            'predictionId': predictionId,
            'status': status['status'],
            'progress': status['progress'],
            'output': status['output'],
            'error': status['error'],
          },
        );

        switch (status['status']) {
          case 'starting':
            setState(() => _progress = 0.1);
            break;
          case 'processing':
            setState(() => _progress = 0.1 +
                (status['progress'] ?? 0) *
                    0.7); // Leave room for upload progress
            break;
          case 'succeeded':
            timer.cancel();
            final videoUrl = status['output'];
            developer.log(
              'Generation succeeded, starting upload',
              name: 'GenerateStockVideoDialog',
              error: {'videoUrl': videoUrl},
            );
            await _uploadToSupabase(videoUrl);
            break;

          case 'failed':
            timer.cancel();
            final errorMessage = status['error'] ?? 'Generation failed';
            developer.log(
              'Generation failed',
              name: 'GenerateStockVideoDialog',
              error: {'error': errorMessage},
            );

            if (!mounted) return;
            setState(() {
              _error = errorMessage;
              _isGenerating = false;
            });
            break;

          default:
            // Keep current progress for unknown states
            break;
        }
      } catch (e, stackTrace) {
        timer.cancel();
        if (!mounted) return;

        developer.log(
          'Error monitoring generation status',
          name: 'GenerateStockVideoDialog',
          error: e,
          stackTrace: stackTrace,
        );

        setState(() {
          _error = e.toString();
          _isGenerating = false;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        width: 500,
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Generate Stock Video',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: _isGenerating
                        ? null
                        : () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              TextFormField(
                controller: _promptController,
                decoration: const InputDecoration(
                  labelText: 'Custom Prompt (Optional)',
                  hintText:
                      'E.g., "Close-up shot of" or "Professional chef preparing"',
                  helperText:
                      'Additional details to enhance the video generation',
                ),
                enabled: !_isGenerating,
                maxLines: 2,
                validator: (value) {
                  if (value != null && value.length > 500) {
                    return 'Prompt must be less than 500 characters';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              Text(
                'Project Description:',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              if (_hasValidDescription)
                Text(
                  widget.project.description,
                  style: Theme.of(context).textTheme.bodyMedium,
                )
              else
                Text(
                  'No project description available. Please add a description to your project before generating a video.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.error,
                      ),
                ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Duration: $_duration seconds',
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                  ),
                  TextButton.icon(
                    icon: const Icon(Icons.timer),
                    label: Text('Toggle ${_duration == 5 ? "10s" : "5s"}'),
                    onPressed: (_isGenerating || !_hasValidDescription)
                        ? null
                        : () {
                            setState(() => _duration = _duration == 5 ? 10 : 5);
                          },
                  ),
                ],
              ),
              if (_error != null) ...[
                const SizedBox(height: 16),
                Text(
                  _error!,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.error,
                  ),
                ),
              ],
              const SizedBox(height: 24),
              if (_isGenerating) ...[
                LinearProgressIndicator(value: _progress),
                const SizedBox(height: 8),
                Text(
                  _getProgressText(),
                  textAlign: TextAlign.center,
                ),
              ] else
                FilledButton.icon(
                  onPressed: _hasValidDescription ? _startGeneration : null,
                  icon: const Icon(Icons.movie_creation),
                  label: const Text('Generate Video'),
                ),
              if (!_hasValidDescription) ...[
                const SizedBox(height: 8),
                TextButton.icon(
                  onPressed: () {
                    Navigator.of(context).pop();
                    // TODO: Navigate to project settings or show edit description dialog
                  },
                  icon: const Icon(Icons.edit),
                  label: const Text('Add Project Description'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _getProgressText() {
    if (_progress < 0.1) return 'Starting generation...';
    if (_progress < 0.9)
      return 'Generating video... ${(_progress * 100).toStringAsFixed(0)}%';
    if (_progress < 0.95)
      return 'Uploading video... ${((_progress - 0.9) * 200).toStringAsFixed(0)}%';
    if (_progress < 1.0) return 'Generating thumbnail...';
    return 'Finalizing...';
  }
}
