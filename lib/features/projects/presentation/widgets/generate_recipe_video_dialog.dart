import 'package:flutter/material.dart';
import 'dart:async';
import '../../data/services/replicate_service.dart';
import '../../domain/entities/media_asset.dart';

class GenerateRecipeVideoDialog extends StatefulWidget {
  final String projectId;
  final Function(MediaAsset) onVideoGenerated;

  const GenerateRecipeVideoDialog({
    super.key,
    required this.projectId,
    required this.onVideoGenerated,
  });

  @override
  State<GenerateRecipeVideoDialog> createState() =>
      _GenerateRecipeVideoDialogState();
}

class _GenerateRecipeVideoDialogState extends State<GenerateRecipeVideoDialog> {
  final _formKey = GlobalKey<FormState>();
  final _replicateService = ReplicateService();

  String _prompt = '';
  int _duration = 15;
  String _style = 'modern cooking';
  bool _isGenerating = false;
  String? _error;
  double _progress = 0;
  Timer? _statusCheckTimer;

  final List<String> _styleOptions = [
    'modern cooking',
    'rustic kitchen',
    'professional chef',
    'home cooking',
    'food vlog',
  ];

  @override
  void dispose() {
    _statusCheckTimer?.cancel();
    super.dispose();
  }

  Future<void> _startGeneration() async {
    if (!_formKey.currentState!.validate()) return;
    _formKey.currentState!.save();

    setState(() {
      _isGenerating = true;
      _error = null;
      _progress = 0;
    });

    try {
      final prediction = await _replicateService.generateRecipeVideo(
        prompt: _prompt,
        durationSeconds: _duration,
        style: _style,
      );

      final predictionId = prediction['id'];
      _monitorGenerationStatus(predictionId);
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isGenerating = false;
      });
    }
  }

  void _monitorGenerationStatus(String predictionId) {
    _statusCheckTimer?.cancel();
    _statusCheckTimer =
        Timer.periodic(const Duration(seconds: 5), (timer) async {
      try {
        final status =
            await _replicateService.checkGenerationStatus(predictionId);

        if (status['status'] == 'succeeded') {
          timer.cancel();
          if (!mounted) return;

          final videoUrl = status['output'];
          // Create a MediaAsset from the generated video
          final mediaAsset = MediaAsset(
            id: predictionId,
            fileName: 'Generated Recipe Video',
            fileUrl: videoUrl,
            projectId: widget.projectId,
            type: MediaType.rawFootage,
            uploadedAt: DateTime.now(),
            fileSize: 0, // Will be updated when the file is downloaded
            position: 0, // Initial position in the timeline
            thumbnailUrl: null, // You might want to generate this
          );

          widget.onVideoGenerated(mediaAsset);
          Navigator.of(context).pop();
        } else if (status['status'] == 'failed') {
          timer.cancel();
          if (!mounted) return;

          setState(() {
            _error = status['error'] ?? 'Generation failed';
            _isGenerating = false;
          });
        } else {
          // Update progress based on status
          if (mounted) {
            setState(() {
              _progress = status['progress'] ?? 0;
            });
          }
        }
      } catch (e) {
        timer.cancel();
        if (!mounted) return;

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
                    'Generate Recipe Video',
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
                decoration: const InputDecoration(
                  labelText: 'Recipe Description',
                  hintText: 'Describe the recipe and cooking process',
                ),
                maxLines: 3,
                enabled: !_isGenerating,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a recipe description';
                  }
                  return null;
                },
                onSaved: (value) => _prompt = value!,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(
                  labelText: 'Video Style',
                ),
                value: _style,
                items: _styleOptions.map((style) {
                  return DropdownMenuItem(
                    value: style,
                    child: Text(style),
                  );
                }).toList(),
                onChanged: _isGenerating
                    ? null
                    : (value) {
                        setState(() => _style = value!);
                      },
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
                  IconButton(
                    icon: const Icon(Icons.remove),
                    onPressed: _isGenerating || _duration <= 15
                        ? null
                        : () {
                            setState(() => _duration = _duration - 5);
                          },
                  ),
                  IconButton(
                    icon: const Icon(Icons.add),
                    onPressed: _isGenerating || _duration >= 60
                        ? null
                        : () {
                            setState(() => _duration = _duration + 5);
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
                  'Generating video... ${(_progress * 100).toStringAsFixed(0)}%',
                  textAlign: TextAlign.center,
                ),
              ] else
                FilledButton.icon(
                  onPressed: _startGeneration,
                  icon: const Icon(Icons.movie_creation),
                  label: const Text('Generate Video'),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
