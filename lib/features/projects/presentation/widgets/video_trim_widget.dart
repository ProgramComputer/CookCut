import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import '../../data/services/openshot_service.dart';
import '../../domain/entities/media_asset.dart';

class VideoTrimWidget extends StatefulWidget {
  final MediaAsset mediaAsset;
  final Function(String) onTrimComplete;

  const VideoTrimWidget({
    super.key,
    required this.mediaAsset,
    required this.onTrimComplete,
  });

  @override
  State<VideoTrimWidget> createState() => _VideoTrimWidgetState();
}

class _VideoTrimWidgetState extends State<VideoTrimWidget> {
  late VideoPlayerController _controller;
  final OpenshotService _openshotService = OpenshotService();
  bool _isLoading = false;
  double _startValue = 0.0;
  double _endValue = 1.0;
  Duration? _duration;
  String? _currentProjectId;
  double _exportProgress = 0.0;

  @override
  void initState() {
    super.initState();
    _initializeVideo();
  }

  Future<void> _initializeVideo() async {
    _controller = VideoPlayerController.network(widget.mediaAsset.fileUrl);
    await _controller.initialize();
    _duration = _controller.value.duration;
    setState(() {});
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _monitorExportProgress(String projectId) async {
    while (_isLoading && mounted) {
      try {
        final progress = await _openshotService.getExportProgress(projectId);
        if (mounted) {
          setState(() => _exportProgress = progress);
        }
        if (progress >= 1.0) break;
        await Future.delayed(const Duration(seconds: 2));
      } catch (e) {
        print('Error monitoring export progress: $e');
      }
    }
  }

  Future<void> _handleTrim() async {
    if (_duration == null) return;

    setState(() {
      _isLoading = true;
      _exportProgress = 0.0;
    });

    try {
      final startTime = Duration(
          milliseconds: (_startValue * _duration!.inMilliseconds).round());
      final endTime = Duration(
          milliseconds: (_endValue * _duration!.inMilliseconds).round());

      final trimmedVideoUrl = await _openshotService.trimVideo(
        videoUrl: widget.mediaAsset.fileUrl,
        startTime: startTime,
        endTime: endTime,
      );

      if (mounted) {
        widget.onTrimComplete(trimmedVideoUrl);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error trimming video: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _exportProgress = 0.0;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_duration == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return Column(
      children: [
        AspectRatio(
          aspectRatio: _controller.value.aspectRatio,
          child: Stack(
            alignment: Alignment.center,
            children: [
              VideoPlayer(_controller),
              if (_isLoading)
                Container(
                  color: Colors.black45,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const CircularProgressIndicator(),
                      const SizedBox(height: 16),
                      Text(
                        'Export Progress: ${(_exportProgress * 100).toStringAsFixed(1)}%',
                        style: const TextStyle(color: Colors.white),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              Row(
                children: [
                  IconButton(
                    icon: Icon(
                      _controller.value.isPlaying
                          ? Icons.pause
                          : Icons.play_arrow,
                    ),
                    onPressed: _isLoading
                        ? null
                        : () {
                            setState(() {
                              _controller.value.isPlaying
                                  ? _controller.pause()
                                  : _controller.play();
                            });
                          },
                  ),
                  Expanded(
                    child: Text(
                      'Duration: ${_duration!.inMinutes}:${(_duration!.inSeconds % 60).toString().padLeft(2, '0')}',
                    ),
                  ),
                  if (_isLoading)
                    Text(
                      'Processing: ${(_exportProgress * 100).toStringAsFixed(1)}%',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                ],
              ),
              const SizedBox(height: 16),
              RangeSlider(
                values: RangeValues(_startValue, _endValue),
                onChanged: _isLoading
                    ? null
                    : (RangeValues values) {
                        setState(() {
                          _startValue = values.start;
                          _endValue = values.end;
                        });
                        final position = Duration(
                          milliseconds:
                              (values.start * _duration!.inMilliseconds)
                                  .round(),
                        );
                        _controller.seekTo(position);
                      },
                labels: RangeLabels(
                  '${(_startValue * _duration!.inSeconds).round()}s',
                  '${(_endValue * _duration!.inSeconds).round()}s',
                ),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _isLoading ? null : _handleTrim,
                icon: _isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.cut),
                label: Text(_isLoading ? 'Processing...' : 'Trim Video'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
